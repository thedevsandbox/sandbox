import random

def randomize_string(str):
  return ''.join(random.sample(str,len(str)))
  
def reverse_string(str):
  return str[::-1]