import asyncio
import json
import logging
from logging.handlers import TimedRotatingFileHandler
import subprocess
from typing import Dict, List, Optional, Any, Union
from mcp.server.fastmcp import FastMCP
from mcp.shared.exceptions import McpError
from mcp.types import ErrorData, INTERNAL_ERROR, INVALID_PARAMS
import os
import signal
import atexit

mcp = FastMCP("xcode-index-mcp", instructions="""
This tool helps you browse and search through Xcode's project index store, which contains information about symbols in your codebase.

It only works on Xcode projects by loading an index file produced by Xcode in the Derived Data folder.

Use `load_index` with the project name to load the store. Ask if you do not know the project name.

When making changes to a symbol, e.g. a function definition, use search_pattern to get the USR ("Unified Symbol Resolution" - a unique identifier) for the symbol. Then use get_occurrances to find references. This will give you file paths and line numbers for each reference.

When requesting symbols from a file use the absoulute path.
     
Example prompt: Show me where "myFunction" is used in my Xcode project.
1. Use search_pattern to find the USR for "myFunction".
2. Use get_occurrences with the USR to find all references to "myFunction" in your codebase.
              
Example prompt: Show me where "myFunction", on line 45 of `source/myClass.swift` is used.
1. Use symbol_occurrences with the filepath and line number to get the USR for "myFunction".
2. Use get_occurrences with the USR to find all references to "myFunction" in your codebase.
              
Example prompt: Remove/rename/reorder/refactor myParameter in myFunction.
1. Use search_pattern to find the USR for "myFunction".
2. Use get_occurrences with the USR to find all references to "myFunction" and the definition. 
3. Remove/refactor the parameter from the definition and all references.
              
Example prompt: refactor the initializer of myClass.
1. Use search_pattern to find the USR for "myClass".
2. Use get_occurrences with the USR to find the definition of "myClass".
3. Use rg -n to search for the initializer in the class's filepath
4. Use symbol_occurences with the filepath and line number to get the USR for the initializer.
5. Use get_occurrences with the USR to find all references to the initializer.
6. Refactor the intializer in the class and all references.
              
Example prompt: Refactor myProperty in myClass.
1. Use search_pattern to find filepath for "myClass".
2. Use `rg -n` to search for the property in the class's filepath
3. Use symbol_occurences with the filepath and line number to get the USR for the property.
4. Use get_occurrences with the USR to find all references to the property.
5. Refactor the property in the class and all references.
""")

# Log directory and file setup
log_dir = os.path.join(os.path.expanduser("~"), ".local", "state", "goose", "logs", "mcps")
os.makedirs(log_dir, exist_ok=True)
log_file = os.path.join(log_dir, "xcode_index_mcp.log")

class SwiftService:
    _instance = None
    _initialized = False

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(SwiftService, cls).__new__(cls)
        return cls._instance

    def __init__(self):
        logger.info("Initialized Swift service object. Not loaded yet.")
        if not SwiftService._initialized:
            self.host = 'localhost'
            self.port = 7949
            self.reader: Optional[asyncio.StreamReader] = None
            self.writer: Optional[asyncio.StreamWriter] = None
            self.swift_process: Optional[subprocess.Popen] = None
            SwiftService._initialized = True
            # Register cleanup on Python process exit
            atexit.register(self._cleanup)

    def _cleanup(self):
        """Cleanup method that runs when Python process exits"""
        logger.info("Running Swift service cleanup on process exit")
        if self.swift_process:
            try:
                # Try to terminate the process group
                os.killpg(os.getpgid(self.swift_process.pid), signal.SIGTERM)
                # Wait a bit for graceful termination
                self.swift_process.wait(timeout=2)
            except (ProcessLookupError, subprocess.TimeoutExpired):
                # If process doesn't exist or doesn't terminate, try force kill
                try:
                    os.killpg(os.getpgid(self.swift_process.pid), signal.SIGKILL)
                except ProcessLookupError:
                    pass
            self.swift_process = None

    async def start(self):
        """Start the Swift MCP service and connect to it."""
        logger.info("Starting Swift service")
        if self.swift_process is None:
             # Set the PATH to include the directory containing the Swift executable
            env = os.environ.copy()
            script_dir = os.path.dirname(os.path.abspath(__file__))
            relative_swift_executable_dir = "../../swift-service/.build/debug"
            swift_executable_dir = os.path.abspath(os.path.join(script_dir, relative_swift_executable_dir))
            env["PATH"] = f"{swift_executable_dir}:{env.get('PATH', '')}"
            logger.info(f"Starting Swift service with executable at: {swift_executable_dir}")

            # Start the Swift MCP service with a new process group
            self.swift_process = subprocess.Popen(
                [
                    "./IndexStoreMCPService",
                ],
                cwd=swift_executable_dir,  # Set the working directory
                env=env,  # Pass the updated environment
                preexec_fn=os.setpgrp  # Create new process group
            )
            
            # Give the service a moment to start
            await asyncio.sleep(2)
            
            # Connect to the service
            await self.connect()

    async def stop(self):
        """Stop the Swift service and clean up connections."""
        logger.info("Stopping Swift service")
        if self.writer:
            self.writer.close()
            await self.writer.wait_closed()
        
        if self.swift_process:
            try:
                # Try to terminate the process group
                os.killpg(os.getpgid(self.swift_process.pid), signal.SIGTERM)
                # Wait a bit for graceful termination
                self.swift_process.wait(timeout=2)
            except (ProcessLookupError, subprocess.TimeoutExpired):
                # If process doesn't exist or doesn't terminate, try force kill
                try:
                    os.killpg(os.getpgid(self.swift_process.pid), signal.SIGKILL)
                except ProcessLookupError:
                    pass
            self.swift_process = None

    async def connect(self):
        """Connect to the Swift MCP service."""
        if not self.reader or not self.writer:
            try:
                self.reader, self.writer = await asyncio.open_connection(self.host, self.port)
                logger.info("Connected to Swift service")
            except Exception as e:
                raise McpError(
                    ErrorData(
                        code=INTERNAL_ERROR,
                        message=f"Failed to connect to Swift service: {str(e)}"
                    )
                )

    async def ensure_connected(self):
        """Ensure the service is started and connected."""
        if self.swift_process is None:
            await self.start()
        elif not self.reader or not self.writer:
            await self.connect()

    async def send_request(self, method: str, params: Dict[str, Any]) -> Dict[str, Any]:
        """Send a request to the Swift service and get the response."""
        await self.ensure_connected()
        logger.info(f"Sending request to swift service: {method}({params})")
        try:
            request = {
                "id": str(id(params)),
                "method": method,
                "params": params
            }

            self.writer.write(json.dumps(request).encode() + b'\n')
            await self.writer.drain()

            response_data = await self.reader.readline()
            response = json.loads(response_data.decode())
            
            if "error" in response and response["error"]:
                logger.error(f"Swift service error: {response['error']}")
                raise McpError(
                    ErrorData(
                        code=INTERNAL_ERROR,
                        message=str(response["error"])
                    )
                )

            result = response["result"]
            if isinstance(result, dict) and "error" in result:
                logger.error(f"Swift service error in result: {result['error']}")
                raise McpError(
                    ErrorData(
                        code=INVALID_PARAMS,
                        message=str(result["error"])
                    )
                )

            return result

        except json.JSONDecodeError as e:
            logger.error(f"Failed to decode Swift service response: {str(e)}")
            raise McpError(
                ErrorData(
                    code=INTERNAL_ERROR,
                    message=f"Failed to decode Swift service response: {str(e)}"
                )
            )
        except Exception as e:
            logger.error(f"Swift service error: {str(e)}")
            raise McpError(
                ErrorData(
                    code=INTERNAL_ERROR,
                    message=f"Swift service error: {str(e)}"
                )
            )

@mcp.tool()
async def load_index(projectName: str) -> bool:
    """
    Load the IndexStore for a project from the Derived Data folder.
    
    Args:
        projectName: Name of the project to load the index for.
    
    Returns:
        bool: True if the index was loaded successfully, False otherwise.
    """
    logger.info(f"Loading index for project: {projectName}")
    try:
        result = await swift_service.send_request("is_available", {"projectName": projectName})
        logger.error(f"Request sent successfully: {result}")
        return result
    except Exception as e:
        logger.error(f"Failed to load index for project '{projectName}': {str(e)}")
        raise McpError(
            ErrorData(
                code=INTERNAL_ERROR,
                message=f"Failed to load index for project '{projectName}': {str(e)}"
            )
        )

@mcp.tool()
async def symbol_occurrences(filePath: str, lineNumber: int) -> Dict[str, Any]:
    """
    Get symbols occurring at a specific location in a file.
    
    Args:
        filePath: Absolute path to the file
        lineNumber: Line number in the file
    
    Returns:
        Dict containing symbol information at the specified location
    """
    try:
        if not isinstance(lineNumber, int) or lineNumber < 1:
            raise McpError(
                ErrorData(
                    code=INVALID_PARAMS,
                    message="lineNumber must be a positive integer"
                )
            )

        params = {
            "filePath": str(filePath),
            "lineNumber": str(lineNumber)
        }
        return await swift_service.send_request("symbol_occurrences", params)

    except McpError:
        raise
    except Exception as e:
        raise McpError(
            ErrorData(
                code=INTERNAL_ERROR,
                message=f"Failed to get symbol occurrences: {str(e)}"
            )
        )

@mcp.tool()
async def get_occurrences(usr: str, roles: List[str]) -> Dict[str, Any]:
    """
    Get all occurrences of a symbol by its USR.
    
    Args:
        usr: The USR (Unified Symbol Resolution) of the symbol
        roles: The roles to search for (must be "reference" or "definition")
    
    Returns:
        Dict containing all occurrences of the symbol
    """
    try:
        valid_roles = ["reference", "definition"]
        invalid_roles = [role for role in roles if role not in valid_roles]
        if invalid_roles:
            raise McpError(
                ErrorData(
                    code=INVALID_PARAMS,
                    message=f"Invalid roles: {invalid_roles}. Must be one of: {valid_roles}"
                )
            )

        params = {
            "usr": str(usr),
            "roles": ",".join(roles)
        }
        return await swift_service.send_request("get_occurrences", params)

    except McpError:
        raise
    except Exception as e:
        raise McpError(
            ErrorData(
                code=INTERNAL_ERROR,
                message=f"Failed to get symbol occurrences: {str(e)}"
            )
        )

@mcp.tool()
async def search_pattern(pattern: str, options: Optional[List[str]] = None) -> Dict[str, Any]:
    """
    Search for symbol occurrences matching a pattern.
    
    Args:
        pattern: The pattern to search for
        options: Optional list of search options. Valid options are:
                - anchorStart: Match pattern at start of symbol name
                - anchorEnd: Match pattern at end of symbol name
                - subsequence: Match pattern as subsequence (not exact match)
                - ignoreCase: Case-insensitive matching
    
    Returns:
        Dict containing matching **canonical** symbol occurrences
    """
    try:
        valid_options = ["anchorStart", "anchorEnd", "subsequence", "ignoreCase"]
        if options:
            invalid_options = [opt for opt in options if opt not in valid_options]
            if invalid_options:
                raise McpError(
                    ErrorData(
                        code=INVALID_PARAMS,
                        message=f"Invalid options: {invalid_options}. Must be one of: {valid_options}"
                    )
                )

        params = {"pattern": str(pattern)}
        if options:
            params["options"] = ",".join(options)
            
        return await swift_service.send_request("search_pattern", params)

    except McpError:
        raise
    except Exception as e:
        raise McpError(
            ErrorData(
                code=INTERNAL_ERROR,
                message=f"Failed to search pattern: {str(e)}"
            )
        )

def configure_logger(log_file_path):
    """
    Removes all console (StreamHandler) loggers from the root logger,
    and attaches a TimedRotatingFileHandler so all logs go to file only.
    No logs will appear in the terminal.
    """
    # 1) Get the root logger
    root_logger = logging.getLogger()

    # 2) Set the overall logging level (DEBUG, INFO, etc.)
    #    If you want fewer messages in your log file, choose INFO or higher.
    root_logger.setLevel(logging.DEBUG)

    # 3) Remove *all* existing handlers (which usually includes the console)
    while root_logger.handlers:
        root_logger.removeHandler(root_logger.handlers[0])

    # 4) Create a rotating file handler
    #    - Rotates at midnight, keeps 30 backups
    #    - You can also use a plain FileHandler if you prefer
    file_handler = TimedRotatingFileHandler(
        filename=log_file_path,
        when="midnight",
        interval=1,
        backupCount=30,
    )

    # 5) Configure a log format
    formatter = logging.Formatter(
        "%(asctime)s - %(levelname)s - [ThreadId(%(thread)d)] %(filename)s:%(lineno)d: %(message)s"
    )
    file_handler.setFormatter(formatter)

    # 6) Attach the file handler to the root logger
    root_logger.addHandler(file_handler)

    return root_logger

logger = configure_logger(log_file)

logger.info("Logger configured successfully.")

# Create a global instance of SwiftService
swift_service = SwiftService()

# Set up signal handlers for clean shutdown
def handle_shutdown(signum, frame):
    logger.info(f"Received signal {signum}, shutting down Swift service...")
    asyncio.run(swift_service.stop())
    logger.info("Swift service shutdown complete")
    os._exit(0)

signal.signal(signal.SIGTERM, handle_shutdown)
signal.signal(signal.SIGINT, handle_shutdown)
