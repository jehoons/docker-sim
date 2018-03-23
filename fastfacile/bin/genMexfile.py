#!/usr/bin/python
import os
import sys

def genMexfile(modelName):
    srcdir = os.path.dirname(os.path.realpath(sys.argv[0]))

    # generate *_mex.c
    s = ''
    for eachline in file(srcdir+'/mex.c'): 
        s += eachline

    s = s.replace('$(MODEL)', modelName)
    f = open(modelName + '_mex.c', 'w')
    f.write(s) 
    f.close() 

    # generate *_mex_mat.c
    s = ''
    for eachline in file(srcdir+'/mex_mat.c'): 
        s += eachline

    s = s.replace('$(MODEL)', modelName)
    f = open(modelName + '_mex_mat.c', 'w')
    f.write(s) 
    f.close() 

if __name__ == '__main__':
    genMexfile(sys.argv[1]) 

