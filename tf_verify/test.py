import sys
sys.path.insert(0, '../ELINA/python_interface/')
sys.path.insert(0, '../deepg/code/')
import constraint_utils
from eran import ERAN
from read_net_file import read_onnx_net
import numpy as np
import tensorflow as tf

eran_ = ERAN(read_onnx_net("~/examples/mnist.onnx")[0], is_onnx=True)

