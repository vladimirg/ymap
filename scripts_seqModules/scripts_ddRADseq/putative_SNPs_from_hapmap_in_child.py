def process_ChildLine(entry_line):
	global chrNums
	global chrName
	global chrCount
	# Process 'SNP_CNV_v1.txt' file line.
	# example lines:
	#       chromosome               coord   total   ref   A    T    G    C
	#       ChrA_C_glabrata_CBS138   45      36      C     0    0    0    36
	#       ChrA_C_glabrata_CBS138   46      37      T     0    37   0    0
	#       ChrA_C_glabrata_CBS138   47      38      A     38   0    0    0
	#       ChrA_C_glabrata_CBS138   48      39      A     39   0    0    0
	child_line = string.strip(entry_line)
	child_line = child_line.split('\t')
	C_chr_name = child_line[0]   # chr name of bp.          : Ca21chrR_C_albicans_SC5314
	C_position = child_line[1]   # chr position of bp.      : 2286371
	C_countTot = child_line[2]   # total count at bp.       : 101
	C_refBase  = child_line[3]   # reference base at bp.    : T
	C_countA   = child_line[4]   # count of A.              : 100
	C_countT   = child_line[5]   # count of T.              : 0
	C_countG   = child_line[6]   # count of G.              : 0
	C_countC   = child_line[7]   # count of C.              : 1
	# Determine chrID associated with chromosome name.
	C_chr = 0
	for x in range(0,chrCount):
		if (chrNums[x] != 0):
			if chrName[x] == C_chr_name:
				C_chr = x+1
	C_chrName = chrName[C_chr-1]
	return C_chr,C_chrName,C_position,C_countA,C_countT,C_countG,C_countC

def process_HapmapLine(entry_line):
	global chrNums
	global chrName
	global chrCount
	# Process 'putative_SNPs_v4.txt' file line.
	# example lines:
	#       chromosome                   coord   HomA   HomB   null
	#       Ca21chr1_C_albicans_SC5314   812     C      T      0
	#       Ca21chr1_C_albicans_SC5314   816     T      C      0
	#       Ca21chr1_C_albicans_SC5314   879     G      A      0
	#       Ca21chr1_C_albicans_SC5314   920     C      T      0
	hapmap_line = string.strip(entry_line)
	hapmap_line = hapmap_line.split('\t')
	H_chr_name  = hapmap_line[0]   # chr name of bp.          : Ca21chrR_C_albicans_SC5314
	H_position  = hapmap_line[1]   # chr position of bp.      : 2286371
	# Determine chrID associated with chromosome name.
	H_chr = 0
	for x in range(0,chrCount):
		if (chrNums[x] != 0):
			if chrName[x] == H_chr_name:
				H_chr = x+1
	H_chrName = chrName[H_chr-1]
	return H_chr,H_chrName,H_position

###
### Preprocesses parent 'putative_SNPs_v4' and child 'SNP_CNV_v1.txt' files to output child lines corresponding
###     to putative_SNP lines near 1:1 in parent file into 'SNP_CNV_v1.txt' file.
### Uses genome definition files to only output data lines for chromosomes of interest.
###

import string, sys, time

genome            = sys.argv[ 1]
genomeUser        = sys.argv[ 2]
projectChild      = sys.argv[ 3]
projectChildUser  = sys.argv[ 4]
hapmap            = sys.argv[ 5]
HapmapUser        = sys.argv[ 6]
main_dir          = sys.argv[ 7]

logName           = main_dir+"users/"+projectChildUser+"/projects/"+projectChild+"/process_log.txt"
inputFile_H       = main_dir+"users/"+HapmapUser+"/hapmaps/"+hapmap+"/SNPdata_parent.txt"
inputFile_C       = main_dir+"users/"+projectChildUser+"/projects/"+projectChild+"/SNP_CNV_v1.txt"

t0 = time.clock()

with open(logName, "a") as myfile:
	myfile.write("*===================================================*\n")
	myfile.write("| Log of 'py/putative_SNPs_from_hapmap_in_child.py' |\n")
	myfile.write("*---------------------------------------------------*\n")


#============================================================================================================
# Find location of genome being used.
#------------------------------------------------------------------------------------------------------------
genomeDirectory = main_dir+"users/"+genomeUser+"/genomes/"+genome+"/"

#============================================================================================================
# Load FastaName from 'reference.txt' for genome in use.
#------------------------------------------------------------------------------------------------------------
with open(logName, "a") as myfile:
	myfile.write("|\tIdentifying name of reference FASTA file.\n")
reference_file = genomeDirectory + '/reference.txt'
refFile        = open(reference_file,'r')
FastaName      = refFile.read().strip()
refFile.close()
FastaName      = FastaName.replace(".fasta", "")

#============================================================================================================
# Process 'preprocessed_SNPs.txt' file for hapmap to determine initial SNP loci.
#------------------------------------------------------------------------------------------------------------
with open(logName, "a") as myfile:
	myfile.write("|\tProcessing parent 'putative_SNPs_v4' file -> het loci.\n")

# Look up chromosome name strings for genome in use.
#     Read in and parse : "links_dir/main_script_dir/genome_specific/[genome]/figure_definitions.txt"
figureDefinition_file  = genomeDirectory + 'figure_definitions.txt'
figureDefinitionFile   = open(figureDefinition_file,'r')
figureDefinitionData   = figureDefinitionFile.readlines()

# Example lines in figureDefinition_file:
#     Chr  Use   Label   Name                         posX   posY   width   height
#     1    1     Chr1    Ca21chr1_C_albicans_SC5314   0.15   0.8    0.8     0.0625
#     2    1     Chr2    Ca21chr2_C_albicans_SC5314   0.15   0.7    *       0.0625
#     0    0     Mito    Ca19-mtDNA                   0.0    0.0    0.0     0.0
with open(logName, "a") as myfile:
	myfile.write("|\tDetermining number of chromosomes of interest in genome.\n")

# Determine the number of chromosomes of interest in genome.
chrName_maxcount = 0
for line in figureDefinitionData:
	line_parts = string.split(string.strip(line))
	chr_num = line_parts[0]
	if chr_num.isdigit():
		chr_num    = int(float(line_parts[0]))
		chr_use    = int(float(line_parts[1]))
		chr_label  = line_parts[2]
		chr_name   = line_parts[3]
		if chr_num > 0:
			if chr_num > chrName_maxcount:
				chrName_maxcount = chr_num
figureDefinitionFile.close()

# Pre-allocate chrName_array
chrName = []
for x in range(0, chrName_maxcount):
	chrName.append([])

with open(logName, "a") as myfile:
	myfile.write("|\tGathering name strings for chromosomes.\n")

# Gather name strings for chromosomes, in order.
figureDefinitionFile  = open(figureDefinition_file,'r')
chrCounter = 0;
chrNums    = [];
chrNames   = [];
chrLabels  = [];
chrShorts  = [];
for line in figureDefinitionData:
	line_parts = string.split(string.strip(line))
	chr_num = line_parts[0]
	if chr_num.isdigit():
		chr_num                        = int(float(line_parts[0]))
		chrNums.append(chr_num);
		chrCounter += chrCounter;
		chr_use                        = int(float(line_parts[1]))
		chr_label                      = line_parts[2]
		chrLabels.append(chr_label);
		chr_name                       = line_parts[3]
		chrNames.append(chr_name);
		chr_nameShort                  = chr_label
		chrShorts.append(chr_nameShort);
		if chr_num != 0:
			chrName[int(float(chr_num))-1] = chr_name
			with open(logName, "a") as myfile:
				myfile.write("|\t\t" + str(chr_num) + " : " + chr_name + " = " + chr_nameShort + "\n")
figureDefinitionFile.close()

# Put the chromosome count into a smaller name for later use.
chrCount = chrName_maxcount
with open(logName, "a") as myfile:
	myfile.write("|\t\tMax chr string : "+str(chrCount)+"\n")
#............................................................................................................

with open(logName, "a") as myfile:
	myfile.write("|\tOpen parent 'putative_SNPs_v4.txt' file.\n")

#............................................................................................................

count            = 0
old_chr          = 0
fragment_found   = 0
last_fragment    = 0
current_fragment = 0
log_count        = 0
log_offset       = 0

print '### Chromosomes of interest : '
for x in range(0,chrCount):
	if (chrNums[x] != 0):
		print '### \t' + str(x+1) + ' : ' + str(chrName[x])

with open(logName, "a") as myfile:
	myfile.write("|\tGathering read coverage data for each fragment.\n")

# Open dataset 'putative_CNVs_v1.txt' file.
data_H = open(inputFile_H,"r")

print '### Data lines for each het locus in parent : [chromosome_name, bp_coordinate, countA, countT, countG, countC]'

# Process 'SNP_CNV_v1.txt' file for both parents, line by line... while checking for missing data.
line_H = data_H.readline()
error_endOfFile = False
while (error_endOfFile == False):
	# bypass comment lines.
	while (line_H[:1] == '#'):
		line_H = data_H.readline()

	H_chrID,H_chrName,H_position = process_HapmapLine(line_H)

	data_C = open(inputFile_C,"r")
	line_C = data_C.readline()
	error_endOfFile = False
	while (error_endOfFile == False):
		C_chrID,C_chrName,C_position,C_countA,C_countT,C_countG,C_countC = process_ChildLine(line_C)
		if (C_chrID == H_chrID) and (C_position == H_position):
			print C_chrName+"\t"+str(C_position)+"\t"+str(C_countA)+"\t"+str(C_countT)+"\t"+str(C_countG)+"\t"+str(C_countC)
			data_C.close()
			break;
		line_C = data_C.readline()
		if not line_C: # EOF 2
			error_endOfFile = True
			data_C.close()
			break;
	if (error_endOfFile == True):
		# data line corresponding to parent SNP was not found in child "SNP_CNV_v1.txt" file.
		print H_chrName+"\t"+str(H_position)+"\t0\t0\t0\t0"
	data_C.close()

	error_endOfFile = False
	line_H = data_H.readline()
	if not line_H: # EOF 1
		error_endOfFile = True
		break
data_H.close()

#------------------------------------------------------------------------------------------------------------
# End of main code block.
#============================================================================================================

print '### End of preprocessed parental SNP, child SNP data.'

with open(logName, "a") as myfile:
	myfile.write("|\tTime to process = " + str(time.clock()-t0) + "\n")
	myfile.write("*---------------------------------------------------*\n")
	myfile.write("| End of 'py/putative_SNPs_from_hapmap_in_child.py' |\n")
	myfile.write("*===================================================*\n")