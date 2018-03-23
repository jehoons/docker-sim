import os,sys,re
import getopt
def SaveRateVariables(vffile,outfile):
    colnames = []
    values = []
    for aline in file(vffile):
        aline=aline.strip()
        if aline=='': continue
        if aline.find('<Parameter Name=') == 0:
            aline = aline.replace('<Parameter Name=','')
            aline = aline.replace('DefaultValue=','')
            aline = aline.replace('/>','')
            aline = aline.replace('\"','')
            splited = aline.split()
            colnames.append(splited[0])
            values.append(splited[1])
    csvfile_singleline = []
    fout1 = open(outfile,'w')
    for col in colnames:
        csvfile_singleline.append('%15s' % col)
    fout1.write(",".join(csvfile_singleline))
    fout1.write("\n")
    csvfile_singleline = []
    for v in values:
        csvfile_singleline.append('%15.8E' % float(v))
    fout1.write(",".join(csvfile_singleline))
    print 'SaveRateVariables: %s is generated.' % outfile

def SaveStateVariables(vffile,outfile):
    colnames = []
    values = []
    for aline in file(vffile):
        aline=aline.strip()
        if aline=='': continue
        if aline.find('<StateVariable Name=') == 0:
            aline = aline.replace('<Parameter Name=','')
            splited = aline.split('\"')
            #splited[1], splited[5]
            colnames.append(splited[1])
            values.append(splited[5])
    csvfile_singleline = []
    fout1 = open(outfile,'w')
    for col in colnames:
        csvfile_singleline.append('%15s' % col)
    fout1.write(",".join(csvfile_singleline))
    fout1.write("\n")
    csvfile_singleline = []
    for v in values:
        csvfile_singleline.append('%15.8E' % float(v))
    fout1.write(",".join(csvfile_singleline))
    print 'SaveStateVariables: %s is generated.' % outfile

def usage():
    print 'optionas and arguments:'
    print '-i vf_file       : give a name for the vf_file.'

def main(argv):
    try:
        opts, args = getopt.getopt(argv,"hi:",["help","input"])
    except getopt.GetoptError:
        print 'use -h or --help to show usage'
        sys.exit(2)
    if opts == []:
        usage()
        sys.exit()
    for opt, arg in opts:
        if opt == '-h':
            usage()
            sys.exit()
        elif opt in ("-i", "--input"):
            vffile = arg

    SaveRateVariables(vffile,'rates.csv')
    SaveStateVariables(vffile,'ivalues.csv')

if __name__=='__main__':
    main(sys.argv[1:])
