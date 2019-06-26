import json
import util

def reverse_string(event, context):
  
    return {
        "message": f"Your reversed string is '{util.reverse_string(event)}'",
        "event": event
    }
