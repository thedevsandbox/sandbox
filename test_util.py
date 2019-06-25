import unittest
import util

class TestUtilMethods(unittest.TestCase):
  
  def test_foo(self):
    self.assertEqual(util.foo(), 'foobar')
    
  def test_reverse_string(self):    
    self.assertEqual(util.reverse_string('foo'), 'oof')
    
if __name__ == '__main__':
  unittest.main()    