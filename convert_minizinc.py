import itertools
import os
import sys
import subprocess
import warnings

file = sys.argv[1]
fbf= ''
cmd="./Debug/bin/kiter -f ./benchmarks/ascenttestbench/one_modem.xml -a createNoC -a randomMapping -a randomRouting -a SymbolicExecutionWP"
out = subprocess.check_output(cmd, shell=True).decode("utf-8")

with open(file) as f:
    for i in f:
        fbf += i
y=[[i.split(',')[1], i.split(',')[3], i.split(',')[5]] for i in fbf.split()]
max_slot = int(max(y, key=lambda x: int(x[2]))[-1]) + 1
noc_node = {int(i) for j in y for i in j[:2]}
tdma = [['0']*len(noc_node) for _ in range(len(noc_node))]
for a,b,c in y:
    tdma[int(a)][int(b)] = c
    
source = []
dest = []
dep = {}
messages = []
m_len = 0
for j in out.split()[3:]:
    i = j.split(',')
    s, d, l, idx, b, deps = i[0], i[1], i[2], i[3], i[4], i[5:]
    source.append(str(int(s)+1))
    dest.append(str(int(d)+1))
    m_len = max(m_len, idx, key = int)
    if 'm'+str(int(idx)+1) in messages:
        raise ValueError("Duplicated message id")
    messages.append('m'+str(int(idx)+1))
    dep[idx]=deps

if int(m_len) != len(messages) - 1:
    warnings.warn("Gaps between message indexes")
actors = ['a'+i for i in sorted(set(source+dest), key=int)]
dependency = [['0']*(int(m_len)+1) for _ in range(int(m_len)+1)]
for k,v in dep.items():
    for i in v:
        dependency[int(k)][int(i)] = '1'

f = open("data.dzn", "w")

f.write("actors={"+','.join(actors)+"};\n")
f.write("messages={"+','.join(messages)+"};\n")
f.write("src=["+','.join(source)+"];\n")
f.write("dst=["+','.join(dest)+"];\n")
f.write("tdma_max="+str(max_slot)+";\n")
for i in range(len(dependency)):
    if i == 0:
        line = ('dependencies=[|')+(','.join(dependency[i]))+('|\n')
    elif i == len(dependency)-1:
        line = ','.join(dependency[i])+'|];\n'
    else:
        line = ','.join(dependency[i])+'|\n'
    f.write(line)
    
for i in range(len(tdma)):
    if i == 0:
        line = ('tdma_table=[|')+(','.join(tdma[i]))+('|\n')
    elif i == len(tdma)-1:
        line = ','.join(tdma[i])+'|];\n'
    else:
        line = ','.join(tdma[i])+'|\n'
    f.write(line)

f.close()

