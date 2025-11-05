from bigquery_agent_app.agent import get_bigquery_agent
from google.adk.sessions import InMemorySessionService
from google.adk.runners import Runner
from google.genai import types
import uuid

APP_NAME = "bigquery_agent_app"
USER_ID = "biquery_user_101"


async def run_conversation(prompt: str):
   """Runs a conversation with the BigQuery agent using the ADK Runner."""

   session_service = InMemorySessionService()
   session_id = f"{APP_NAME}-{uuid.uuid4().hex[:8]}"
   root_agent = get_bigquery_agent()

   runner = Runner(
       agent=root_agent, app_name=APP_NAME, session_service=session_service
   )
   session = await session_service.create_session(
       app_name=APP_NAME, user_id=USER_ID, session_id=session_id
   )
   final_response_text = "Unable to retrieve final response."
   tool_calls = []

   try:
       # Run the agent and process the events as they are generated
       async for event in runner.run_async(
           user_id=USER_ID,
           session_id=session_id,
           new_message=types.Content(role="user", parts=[types.Part(text=prompt)]),
       ):

           if (
               event.content
               and event.content.parts
               and event.content.parts[0].function_call
           ):

               func_call = event.content.parts[0].function_call

               tool_call = {
                   "tool_name": func_call.name,
                   "tool_input": dict(func_call.args),
               }
               tool_calls.append(tool_call)

           if event.is_final_response():
               if event.content and event.content.parts:
                   final_response_text = event.content.parts[0].text
               break

   except Exception as e:
       print(f"Error in run_conversation: {e}")
       final_response_text = f"An error occurred during the conversation: {e}"

   return {
       "response": final_response_text,
       "predicted_trajectory": tool_calls
   }