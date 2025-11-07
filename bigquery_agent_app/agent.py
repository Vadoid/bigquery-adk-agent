from google.adk.agents import Agent
from google.adk.tools.bigquery import BigQueryCredentialsConfig, BigQueryToolset
import google.auth
import dotenv
import os # Import os for better path handling (optional, but good practice)
import sys # Import sys for exiting the application (critical for Uvicorn stability)
from pathlib import Path

# Get the project root directory (parent of bigquery_agent_app)
PROJECT_ROOT = Path(__file__).parent.parent
ENV_FILE = PROJECT_ROOT / ".env"

# Load .env file from project root
dotenv.load_dotenv(ENV_FILE)

# Read configuration from environment variables
GOOGLE_CLOUD_PROJECT = os.getenv("GOOGLE_CLOUD_PROJECT")
BIGQUERY_DATASET = os.getenv("BIGQUERY_DATASET", "icecream_lab")  # Default to icecream_lab if not set

# Validate required environment variables
if not GOOGLE_CLOUD_PROJECT:
    raise ValueError(
        "GOOGLE_CLOUD_PROJECT environment variable is required. "
        "Please set it in your .env file or environment."
    )

print(f"✅ Using project: {GOOGLE_CLOUD_PROJECT}, dataset: {BIGQUERY_DATASET}")

# Helper function to replace placeholders in instruction strings
def replace_instruction_placeholders(instruction_text: str) -> str:
    """Replace {PROJECT_ID} and {DATASET_NAME} placeholders with actual values from env."""
    return instruction_text.replace("{PROJECT_ID}", GOOGLE_CLOUD_PROJECT).replace(
        "{DATASET_NAME}", BIGQUERY_DATASET
    )

# --- Fallback Instruction (Used only if file loading fails) ---
# YOU MUST ensure this fallback is sufficient to describe the agent's core function.
FALLBACK_INSTRUCTION_TEMPLATE = """
You are a BigQuery data analysis agent.
You are able to answer questions on data stored in project-id: '{PROJECT_ID}' on the `{DATASET_NAME}` dataset.
Note: Your detailed analysis protocol file was not found. Please operate based on general SQL query generation.
"""
# -------------------------------------------------------------


# 1. Define the path to your instructions file
INSTRUCTION_FILE_PATH = "agent_instructions.txt"

# 2. Load the instructions from the file with improved error handling
try:
    with open(INSTRUCTION_FILE_PATH, 'r') as f:
        # Load the entire content as a single string
        comprehensive_instructions = f.read()
        print(f"✅ Successfully loaded instructions from {INSTRUCTION_FILE_PATH}")
        # Combine the base and comprehensive instructions
        agent_instruction_content_template = (
            """
            You are a BigQuery data analysis agent.
            You are able to answer questions on data stored in project-id: '{PROJECT_ID}' on the `{DATASET_NAME}` dataset.
            
            ---
            
            # Comprehensive Data Analysis Protocol:
            
            """
            + comprehensive_instructions
        )
        # Replace placeholders with actual values from environment
        agent_instruction_content = replace_instruction_placeholders(agent_instruction_content_template)

except FileNotFoundError:
    # CRITICAL FIX: If the file is not found, log the error and use the defined fallback.
    print(f"❌ CRITICAL ERROR: Instruction file not found at {INSTRUCTION_FILE_PATH}.")
    print("⚠️ Defining agent with FALLBACK INSTRUCTION. Execution may be limited.")
    agent_instruction_content = replace_instruction_placeholders(FALLBACK_INSTRUCTION_TEMPLATE)


# 3. Initialize Credentials and Tools
credentials, _ = google.auth.default()
credentials_config = BigQueryCredentialsConfig(credentials=credentials)
bigquery_toolset = BigQueryToolset(
    credentials_config=credentials_config
)


# 4. Define the Agent object
root_agent = Agent(
    model="gemini-2.5-flash",
    name="bigquery_agent",
    description="Agent that answers questions about BigQuery data by executing SQL queries.",
    # Use the content determined in the try/except block
    instruction=agent_instruction_content, 
    tools=[bigquery_toolset]
)

# 5. Define the Agent Getter Function
def get_bigquery_agent():
    return root_agent