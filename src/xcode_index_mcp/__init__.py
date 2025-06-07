from .server import mcp
from .server import swift_service
from .server import logger

def main():
    logger.info("Entered main()")
    mcp.run()

if __name__ == "__main__":
    main()