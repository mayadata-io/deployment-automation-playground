#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
Pseudo fencing utility for Kubernetes.
Monitors the status of the nodes and if a node stays not "Ready" for 60 seconds:
- Delete the volumeAttachments on the node
- Force delete the pods on the node

NOTE: There is no validation of the node actually being down, so production use is risky

Usage: 
pseudo-fence.py /path/to/admin.conf
- admin.conf being the KUBECONFIG file from the K8S cluster
'''

from kubernetes import client, config
import sys, os
import time

def get_nodes(core):
    nodes = {}
    n = core.list_node()
    for node in n.items:
        name = node.metadata.name
        for i in node.status.conditions:
            if i.type == "Ready":
                nodes[name] = i.status
    return nodes

def get_volumeattachments(stor, node):
    volumes = []
    va = stor.list_volume_attachment()
    for volume in va.items:
        if volume.spec.node_name == node:
            volumes.append(volume.metadata.name)
    return volumes

def delete_volumeattachments(stor, node):
    volumes = get_volumeattachments(stor, node)
    for va in volumes:
        stor.delete_volume_attachment(va)
        print("Deleting VA %s" % va)

def get_pods(core, namespace):
    pods = []
    p = core.list_namespaced_pod(namespace)
    for pod in p.items:
        for i in pod.status.conditions:
            if i.type == "Ready":
                pods.append({'name': pod.metadata.name, 'node': pod.spec.node_name, 'ready': i.status})
    return pods

def force_delete_pod(core, pod, namespace):
    try: 
        core.delete_namespaced_pod(pod, namespace=namespace, grace_period_seconds=0)
        print("Force deleting pod %s" % pod)
    except:
        pass

def main():
    if len(sys.argv) > 1:    
        kubeconfig = sys.argv[1]
    else:
        if 'KUBECONFIG' in os.environ.keys():
            kubeconfig = os.environ['KUBECONFIG']
        else:
            print("KUBECONFIG not set in environment vars or as an argument")
            sys.exit(1)

    config.load_kube_config(kubeconfig)
    core = client.CoreV1Api()
    stor = client.StorageV1Api()
    starttime = time.time()
    
    downcounter = {}
    podcounter = {}
    print("Loading KUBECONFIG from %s" % kubeconfig)
    while True:
        time.sleep(5)
        nodes = get_nodes(core)
        for node in nodes.keys():
            if node not in downcounter.keys():
                downcounter[node] = time.time()
            if nodes[node] == 'True':
                downcounter[node] = time.time()
            else:
                pass
        for node in downcounter.keys():
            if (time.time() - downcounter[node]) > 60:
                delete_volumeattachments(stor, node)
        pods = get_pods(core, 'default')
        for pod in pods:
            if pod['name'] not in podcounter.keys():
                podcounter[pod['name']] = time.time()
            if pod['ready'] == 'True':
                podcounter[pod['name']] = time.time()
            else:
                pass
        for pod in list(podcounter):
            if (time.time() - podcounter[pod]) > 180:
                force_delete_pod(core, pod, 'default')
                del(podcounter[pod])

main()
