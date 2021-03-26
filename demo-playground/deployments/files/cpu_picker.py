import os, sys

lscpu = os.popen('lscpu')
lscpu = lscpu.read()
numacores = {}
for i in lscpu.splitlines():
    if i.startswith('NUMA node') and not i.startswith('NUMA node(s)'):
        node = i.split('NUMA node')[1].split()[0]
        numacores[node] = i.split()[-1]
isolcpus = []
for i in numacores.keys():
    if len(numacores[i].split('-')) > 1:
        core0 = numacores[i].split('-')[0]
        coreN = numacores[i].split('-')[-1]
        if int(coreN) - int(core0) > 4:
            for n in range(int(coreN), int(coreN) - 4, -1):
                isolcpus.append(str(n))
        elif int(coreN) - int(core0) > 2:
            for n in range(int(coreN), int(coreN) - 2, -1):
                isolcpus.append(str(n))
        else:
            pass
    elif len(numacores[i].split(',')) > 1:
        cores = numacores[i].split(',')
        if len(cores) > 4:
            for n in range(len(cores), len(cores) - 4, -1):
                isolcpus.append(cores[n-1])
        elif len(cores) > 2:
             for n in range(len(cores), len(cores) - 2, -1):
                isolcpus.append(cores[n-1])
        else:
            pass
if len(isolcpus) < 4:
    print('Could not find the minimum required 4 cores, exiting')
    sys.exit(1)

print(','.join(isolcpus))

