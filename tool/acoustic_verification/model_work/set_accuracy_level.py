"""Sets accuracy_level on every MatMulNBits node of a quantized model (weights
untouched): 4 = the activations are quantized to int8 for the multiply (ONNX
Runtime's int8 kernels: ARM dot-product / x86 VNNI), 0 = float.

  python set_accuracy_level.py <in.onnx> <out.onnx> [--level 4]
"""
import sys
import onnx
from onnx import helper

src, out = sys.argv[1], sys.argv[2]
level = int(sys.argv[sys.argv.index('--level') + 1]) if '--level' in sys.argv else 4
m = onnx.load(src)
n = 0
for node in m.graph.node:
    if node.op_type != 'MatMulNBits':
        continue
    for a in list(node.attribute):
        if a.name == 'accuracy_level':
            node.attribute.remove(a)
    node.attribute.append(helper.make_attribute('accuracy_level', level))
    n += 1
onnx.save(m, out)
print(f'{out}: accuracy_level {level} on {n} MatMulNBits')
