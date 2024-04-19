import os
from .eran import ERAN
from .read_net_file import read_onnx_net, read_tensorflow_net
import tensorflow as tf
tf1 = tf.compat.v1

# Adapted from testing/check_models.py
def from_file(netname):
    _, extension = os.path.splitext(netname)

    if   extension == ".onnx":
        return from_onnx (netname)
    elif extension == ".keras":
        return from_keras(netname)
    elif extension == ".meta":
        return from_meta (netname)
    elif extension == ".pb":
        return from_pb   (netname)
    elif extension == ".tf":
        return from_tf   (netname)
    elif extension == ".pyt":
        return from_pyt  (netname)
    raise ValueError(f"Invalid graph type `{extension}`. Must be one of .onnx, .keras, .meta, .pb, .tf, .pyt")

def from_onnx(netname):
    model, _ = read_onnx_net(netname)
    return ERAN(model, is_onnx=True)

def from_keras(netname):
    model = tf.keras.models.load_model(netname)
    return ERAN(model)

non_layer_operation_types = []
def from_sess(netname, sess):
    ops = sess.graph.get_operations()
    last_layer_index = -1
    while ops[last_layer_index].type in non_layer_operation_types:
        last_layer_index -= 1
    out_tensor = sess.graph.get_tensor_by_name(ops[last_layer_index].name + ":0")
    return ERAN(out_tensor, sess)
def from_meta(netname):
    netfolder = os.path.dirname(netname)
    sess = tf1.Session()
    saver = tf1.train.import_meta_graph(netname)
    saver.restore(sess, tf1.train.latest_checkpoint(netfolder + '/'))
    return from_sess(netname, sess)
def from_pb(netname):
    sess = tf1.Session()
    with tf1.gfile.GFile(netname, "rb") as f:
        graph_def = tf1.GraphDef()
        graph_def.ParseFromString(f.read())
        sess.graph.as_default()
        tf1.graph_util.import_graph_def(graph_def, name='')
    return from_sess(netname, sess)

def from_text(netname, is_pyt=False):
    with open(netname, "r") as f:
        lines = f.readlines()
    inputs = lines[1].split("]", 1)[0]
    input_size = len(inputs.split(","))
    sess = tf1.Session()
    model, _, _, _ = read_tensorflow_net(netname, input_size, is_pyt)
    return ERAN(model, sess)
def from_tf(netname):
    return from_text(netname, False)
def from_pyt(netname):
    return from_text(netname, True)

