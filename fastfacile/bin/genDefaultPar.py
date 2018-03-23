#!/usr/bin/python
import os, unittest, sys

def Rates(argv):
    filename = argv[0]
    found_target_section = False 
    rates_lines = [ ] 
    for a_line in file(filename):
        a_line = a_line.strip()
        if a_line == '' or a_line[0] == '#':
            continue 
        # first find and set found_target_section 
        if a_line == 'EQN:':
            found_target_section = True
            continue 
        # found another section? 
        if found_target_section == True and a_line[-1] == ':':
            break
        if found_target_section: 
            if a_line[:8] == 'variable':
                rates_lines.append(a_line)

    labels = [ ] 
    values = [ ]
    for a in rates_lines:
        a = a.replace('variable', '')
        a = a.strip()
        a = a.split('#')
        a = a[0]
        a = a.split('=')
        labels.append(a[0].strip())
        values.append(a[1].strip())

    values = [value for value in values]
    labels = ['\''+label+'\'' for label in labels]
    project = filename.split('.')[0]
    fout = open('%s_rates.m' % project,'w')

    fout.write("function [values] = %s_rates()\n" % project)
    fout.write('values = [' + ",".join(values)+'];\n');
    fout.close() 

def Ivalues(argv):
    filename = argv[0]
    found_target_section = False 
    ivalues_lines = [ ] 
    for a_line in file(filename):
        a_line = a_line.strip()
        if a_line == '' or a_line[0] == '#':
            continue 
        # first find and set found_target_section 
        if a_line == 'INIT:':
            found_target_section = True
            continue 
        # found another section? 
        if found_target_section == True and a_line[-1] == ':':
            break
        if found_target_section: 
            ivalues_lines.append(a_line)

    labels = [ ] 
    values = [ ]
    for a in ivalues_lines:
        a = a.strip()
        a = a.split('=')
        labels.append(a[0].strip())
        values.append(a[1].strip())

    values = [value for value in values]

    values = [value.replace('uM','') for value in values]

    labels = ['\''+label+'\'' for label in labels]
    project = filename.split('.')[0]
    fout = open('%s_ivalues.m' % project,'w')

    fout.write("function [values] = %s_ivalues()\n" % project)
    fout.write('values = [' + ",".join(values)+'];\n');
    fout.close()

if __name__ == '__main__':
    Ivalues(sys.argv[1:])
    Rates(sys.argv[1:])

