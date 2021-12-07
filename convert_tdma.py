import itertools
import sys

file = sys.argv[0]
fbf= ''
with open(file) as f:
    for i in f:
        fbf += i
y=[[i.split(',')[1], i.split(',')[3], i.split(',')[5]] for i in fbf.split()]
max_slot = int(max(y, key=lambda x: int(x[2]))[-1]) + 1
noc_node = {int(i) for j in y for i in j[:2]}
res = [['0']*len(noc_node) for _ in range(len(noc_node))]
for a,b,c in y:
    res[int(a)][int(b)] = c

f = open("res.txt", "w")
for i in res:
    f.write(','.join(i))