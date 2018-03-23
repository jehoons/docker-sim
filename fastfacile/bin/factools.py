#!/usr/bin/python
import os, unittest, sys

template_ratesLabels = """% author: Je-Hoon Song
function labels = ratesLabels(i)
labels = {@labels};
if nargin == 1
    labels = labels{i};
end
"""

template_statesLabels = """% author: Je-Hoon Song
function labels = statesLabels(i)
labels = {@labels};
if nargin == 1
    labels = labels{i};
end
"""

def MapleToVfgen(inputfile) :
    currentBlockType = '?' # EQN, INIT, MOIETY PROBE BIFURC_PARAM:
    ivaluesDict = {}
    constantDict = {} 
    expressionDict = {}
    speciesDict = {}
    dependentSpeciesDict = {} 
    ivaluesList = []
    constantsList = []
    for a_line in file(inputfile):
        a_line = a_line.strip()
        if a_line == '': continue
        #if a_line[0] == '#': continue
        if a_line.find(' #') > -1:
            a_line = a_line[0:a_line.find(' #')]
        if a_line == '# initial values' :
            currentBlockType = 'iv'
            continue
        elif a_line == '# constants' :
            currentBlockType = 'con'
            continue
        elif a_line == '# dependent species' :
            currentBlockType = 'depspec'
            continue
        elif a_line == '# expressions' :
            currentBlockType = 'expr'
            continue
        elif a_line == '# ode for independent species' :
            currentBlockType = 'species'
            continue                        
        if currentBlockType == 'iv':
            if a_line[0] == '#' : continue
            words = a_line.split(':=')
            words[1] = words[1].replace(';','')
            ivaluesDict[words[0][1:].strip()] = words[1].strip()
            ivaluesList.append(words[0][1:].strip())
        elif currentBlockType == 'con':
            if a_line[0] == '#' : continue
            words = a_line.split(':=')
            words[1] = words[1].replace(';','')
            constantDict[words[0].strip()] = words[1].strip()
            constantsList.append(words[0].strip())
        elif currentBlockType == 'expr':
            if a_line[0] == '#' : continue
            words = a_line.split(':=')
            words[1] = words[1].replace(';','')
            expressionDict[words[0].strip()] = words[1].strip()
        elif currentBlockType == 'species':
            if a_line[0] == '#' : continue
            words = a_line.split(':=')
            words[1] = words[1].replace(';','')
            words[0] = words[0][1:]
            words[0] = words[0][0:-3]
            speciesDict[words[0].strip()] = words[1].strip()
        elif currentBlockType == 'depspec':
            if a_line[0] == '#' : continue
            words = a_line.split(':=')
            words[1] = words[1].replace(';','')
            dependentSpeciesDict[words[0].strip()] = words[1].strip()

    print '<?xml version="1.0"?>'
    print '<VectorField Name="%s">' % (os.path.basename(inputfile).split('.'))[0]

    # print parameter section: 
    for a_key in constantsList: 
        print '<Parameter Name="%s"' % a_key, 
        print 'DefaultValue="%s"' % constantDict[a_key], 
        print '/>'

    # print expression (for dependent species) section: 
    for a_key in dependentSpeciesDict: 
        print '<Expression Name="%s"' % a_key, 
        print 'Formula="%s"' % dependentSpeciesDict[a_key], 
        print '/>'

    # print expression section: 
    for a_key in expressionDict: 
        print '<Expression Name="%s"' % a_key, 
        print 'Formula="%s"' % expressionDict[a_key], 
        print '/>'

    # print statevariable section: 
    for a_key in ivaluesList: 
        print '<StateVariable Name="%s"' % a_key, 
        print 'Formula="%s"' % speciesDict[a_key], 
        print 'DefaultInitialCondition="%s"' % ivaluesDict[a_key], 
        print '/>'

    print '</VectorField>'

    #ivaluesDict = {}
    #constantDict = {} 
    print 
    print '<!-- '
    print '#include "%s_cv.h"' % (os.path.basename(inputfile).split('.'))[0]
    print 'const int N_ = %d;' % len(ivaluesDict)
    print 'const int P_ = %d;' % len(constantDict)
    print 'realtype def_y_[%d] = {' % len(ivaluesDict), 
    _firstQ = True
    for a_ivs in ivaluesList: 
        if _firstQ:
            print 'RCONST(%s)' % ivaluesDict[a_ivs], 
            _firstQ = False
        else:
            print ', RCONST(%s)' % ivaluesDict[a_ivs], 
    print '};'

    print 'const realtype def_p_[%d] = {' % len(constantDict), 
    _firstQ = True
    for a_cons in constantsList: 
        if _firstQ:
            print 'RCONST(%s) ' % constantDict[a_cons], 
            _firstQ = False
        else:
            print ', RCONST(%s) ' % constantDict[a_cons], 
    print '}; '

    print 'realtype y_[%d];' % len(ivaluesDict)
    print 'realtype p_[%d];' % len(constantDict)

    print 'char *varnames_[%d] = {' % len(ivaluesDict), 
    _firstQ = True
    for a_ivs in ivaluesList: 
        if _firstQ:
            print '"'+a_ivs+'"', 
            _firstQ = False
        else:
            print ',', '"'+a_ivs+'"', 
    print '}; '
    
    print 'char *parnames_[%d] = {' % len(constantDict), 
    _firstQ = True
    for a_cons in constantsList: 
        if _firstQ:
            print '"'+a_cons+'"', 
            _firstQ=False 
        else:
            print ',', '"'+a_cons+'"', 
    print '}; '

    # print molecular names with matlab style 
    print 'stateLbl = {', 
    _firstQ = True
    for a_ivs in ivaluesList: 
        if _firstQ:
            print '\''+a_ivs+'\'', 
            _firstQ = False
        else:
            print ',', '\''+a_ivs+'\'', 
    print '}; '

    f = open('statesLabels.m', 'w')
    stateNamesStr = ",".join([ "'%s'" % state for state in ivaluesList])
    code_statesLabels = template_statesLabels.replace('@labels',stateNamesStr)
    f.write(code_statesLabels) 
    f.close()

    # print parameter names with matlab style
    print 'rateLbl = {', 
    _firstQ = True
    for a_cons in constantsList: 
        if _firstQ:
            print '\''+a_cons+'\'', 
            _firstQ = False
        else:
            print ',', '\''+a_cons+'\'', 
    print '}; '

    f = open('ratesLabels.m', 'w')
    rateNamesStr = ",".join([ "'%s'" % rate for rate in constantsList])
    code_ratesLabels = template_ratesLabels.replace('@labels',rateNamesStr)
    f.write(code_ratesLabels) 
    f.close()

    # print default parameter ranges with matlab style
    print 'ratesRange = {' 
    # _firstQ = True
    for a_cons in constantsList: 
        print '\t\'%s\',\t1.0e-3,\t1.0e+3' % a_cons  
    print '};'

    # print default parameter ranges with matlab style
    print 'ratesRange = [' 
    # _firstQ = True
    for a_cons in constantsList: 
        print '\t1.0e-3,\t1.0e+3\t%% %s' % a_cons  
    print '];'

    print 'parfix = [' 
    # _firstQ = True
    for a_cons in constantsList: 
        print '\t1e-3,\t0\t%% %s' % a_cons  
    print '];'

    print '-->'

    MakeOdeSizeH(inputfile,constantDict,ivaluesDict,ivaluesList,constantsList)
    MakeOdeEngineOde23(inputfile)

    return ivaluesDict, constantDict

def MakeOdeEngineOde23(inputfile):
    projectName  = inputfile.split('.')[0]
    matlabFunctionName  = inputfile.split('.')[0] + '_engine'
    filename = inputfile.split('.')[0] + '_engine' + '.m'
    f = open(filename, 'w')

    code = """ %%author: Je-Hoon Song email: gistmecha@gmail.com
function [output, yf, flag] = %s(tvec, ivalues, rates, modeString)
%% modeString - builtin | mex
if nargin < 3
    error('Number of argument should be greater than 3!');
elseif nargin < 4
    modeString = '';
end

%% check the dimensions of inputs, and then correct the input data
ivaluesSize = size(ivalues,1); 
ratesSize = size(rates,1); 
if ivaluesSize == ratesSize
    %% nothing to do!
elseif ivaluesSize == 1
    ivaluesNew = ones(ratesSize,1)*ivalues; 
    ivalues = ivaluesNew; 
elseif ratesSize == 1
    ratesNew = ones(ivaluesSize,1)*rates; 
    rates = ratesNew; 
else 
    error('unknown dimension of inputs, ivalues and rates');
end

if strcmp(modeString,'builtin')
    [output, yf, flag] = BuiltInSolver(tvec, ivalues, rates);
    return ;
end
if strcmp(modeString,'mex')
    [output, yf, flag] = MexSolver(tvec, ivalues, rates);
    return ;
end

%% automatic detection of solver by try-catch
try
    [output, yf, flag] = MexSolver(tvec, ivalues, rates);
catch err
    [output, yf, flag] = BuiltInSolver(tvec, ivalues, rates);
end

function [output, yf, flag] = BuiltInSolver(tvec, ivalues, rates)
N = size(ivalues,1);
yf = zeros(size(ivalues)); 
flag = zeros(N,1);

isOpen = matlabpool('size') > 0; 
if isOpen == 0 && N > 10
    matlabpool open
end

parfor i = 1 : N
    [t, y] = ode23s(@%s_odes, tvec, ivalues(i,:), odeset(), rates(i,:));
    output{i, 1} = y;
    yf(i, :) = y(end, :); 
end

function [output, yf, flag] = MexSolver(tvec, ivalues, rates)
    [output, yf, flag] = %s_mex(tvec, ivalues, rates); """ \
            % (matlabFunctionName, projectName, projectName)
    f.write(code) 
    f.close()

def MakeOdeSizeH(inputfile,constantDict,ivaluesDict,ivaluesList,constantsList):
    f = open('ode_size.h', 'w')
    # print parameter names with matlab style
    f.write('#ifndef _ode_size_h_\n')
    f.write('#define _ode_size_h_\n')
    f.write('#include "%s_cv.h"\n' % (os.path.basename(inputfile).split('.'))[0])
    f.write('#define __N_SPECIES__      %d\n' % len(ivaluesDict))
    f.write('#define __N_PARAMETERS__   %d\n' % len(constantDict))
    f.write('const int N_ = %d;\n' % len(ivaluesDict))
    f.write('const int P_ = %d;\n' % len(constantDict))
    f.write('realtype def_y_[%d] = { ' % len(ivaluesDict)) 
    s = []
    for iv in ivaluesList:
        s.append('RCONST(%s)' % ivaluesDict[iv])
    f.write(",".join(s))
    f.write(" };\n")
    f.write('const realtype def_p_[%d] = { ' % len(constantDict))
    s = []
    for p in constantsList:
        s.append('RCONST(%s)' % constantDict[p])
    f.write(",".join(s))
    f.write(" };\n")
    f.write('realtype y_[%d];\n' % len(ivaluesDict))
    f.write('realtype p_[%d];\n' % len(constantDict))
    f.write('char *varnames_[%d] = { ' % len(ivaluesDict))
    s = []
    for iv in ivaluesList:
        s.append('\"%s\"'%iv)
    f.write(",".join(s))
    f.write(' };\n')
    f.write('char *parnames_[%d] = { ' % len(constantDict))
    s = []
    for p in constantsList:
        s.append('\"%s\"'%p)
    f.write(",".join(s))
    f.write(' };\n')
    f.write('#endif\n')    
    f.close()

def main(argv):
    MapleToVfgen(argv[0])

if __name__ == '__main__':
    main(sys.argv[1:])

