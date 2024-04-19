import sys
sys.path.insert(0, '../ELINA/python_interface/')
sys.path.insert(0, '../deepg/code/')
from .ml_constraints import Constraints
from . import ERAN
from .read_net_file import read_onnx_net
import numpy as np
import tensorflow as tf

eran_ = ERAN(read_onnx_net(sys.argv[1])[0], is_onnx=True)
constraints = Constraints.from_label((2,))
specLB = np.zeros(eran_.input_shape)
specUB = np.full(eran_.input_shape, sys.argv[2])

out = eran_.analyze_box(specLB, specUB, "deeppoly", 1, 1, True, constraints)

