#!/usr/bin/python
'''genRange.py generates range.m file.
'''
import os, unittest, sys
head = """function [lb, ub] = ranges()
lbub = [
"""

tail = """];
lb = lbub(:,1)';
ub = lbub(:,2)';
"""

default_min = '1.0E-1'
default_max = '1.0E+1'

def take_data(s):
    parts = s.split('#')
    left_words = parts[0].split()
    if len(parts) == 1:
        return left_words[1].strip(), \
                default_min, \
                default_max 

    right = parts[1].strip()
    right = right.replace('{','')
    right = right.replace('}','')
    right_words = right.split(',')
    return left_words[1].strip(), \
            right_words[0].strip(), \
            right_words[1].strip()

def main(argv):
    parameter_range_list = []
    for a_line in file(argv[0]):
        a_line = a_line.strip()
        if a_line == '' or a_line[0] == '#':
            continue 
        if a_line.find('variable', 0) != -1:
            varname, minv, maxv = take_data(a_line)
            a_range = [varname, minv, maxv]
            parameter_range_list.append(a_range) 

    fout = open('ranges.m','w')
    fout.write(head)

    for a_range in parameter_range_list:
        s = a_range[1] + ' ' + a_range[2] + ' % ' + a_range[0] + '\n'
        fout.write(s)

    fout.write(tail)

if __name__ == '__main__':
    main(sys.argv[1:])

