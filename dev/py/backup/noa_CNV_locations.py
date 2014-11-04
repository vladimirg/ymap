# Input Arguments
#   1) user       : 'darren'
#   2) project    : 'test_Ca'
#   3) genome     : 'Candida_albicans_SC5314_etc'
#   4) genomeUser : ''
#   5) main_dir   : '/home/bermanj/shared/links/'
#	6) logName    :
#
# Process input files:
#	1) Raw CNV data                 : $workingDir"users/"$user"/projects/"$project"/SNP_CNV_v1.txt".
#	2) FASTA file name              : $workingDir"users/default/genomes/default/reference.txt",
#	                               or $workingDir"users/"$user"/genomes/default/reference.txt" as $FastaName.
#	3) Coordinates of standard bins : $workingDir"users/default/genomes/"$genome"/"$FastaName".standard_bins.fasta",
#	                               or $workingDir"users/"$user"/genomes/"$genome"/"$FastaName".standard_bins.fasta".

# Generate output file:
#	1) a simplified pileup file containing average read counts per standard bin.   [chr_num,bp_start,bp_end, data_ave]
#		0) chr_num   : Numerical chromosome identifier, defined for each genome in "figure_details.txt".
#		1) bp_start  : Start bp coordinate along chromosome.
#		2) bp_end    : End bp coordinate along chromosome.
#		3) reads_ave : Average reads across fragment.
#		Comment lines in output begin with '#'.
#

import string, sys, re, time
user       = sys.argv[1]
project    = sys.argv[2]
genome     = sys.argv[3]
genomeUser = sys.argv[4]
main_dir   = sys.argv[5]
logName    = sys.argv[6]
inputFile  = main_dir+"users/"+user+"/projects/"+project+"/SNP_CNV_v1.txt"

# Variables defining CNV peaks to find.
sizeMin    = 100
sizeMax    = 15000
minDiff    = 1.5




t0 = time.clock()

with open(logName, "a") as myfile:
	myfile.write("\t\t\t*======================================================================*\n")
	myfile.write("\t\t\t| Log of 'dataset_process_for_CNV_analysis.py'                         |\n")
	myfile.write("\t\t\t*----------------------------------------------------------------------*\n")

#============================================================================================================
# Find location of genome being used.
#------------------------------------------------------------------------------------------------------------
genomeDirectory = main_dir+"users/"+genomeUser+"/genomes/"+genome+"/"

with open(logName, "a") as myfile:
	myfile.write("\t\t\t|\n")
	myfile.write("\t\t\t|\tProcessing standard bin fragmented genome file.\n")

#============================================================================================================
# Load FastaName from 'reference.txt' for genome in use.
#------------------------------------------------------------------------------------------------------------
with open(logName, "a") as myfile:
	myfile.write("\t\t\t|\tIdentifying name of reference FASTA file.\n")
reference_file = genomeDirectory + '/reference.txt'
refFile        = open(reference_file,'r')
FastaName      = refFile.read().strip()
refFile.close()
FastaName      = FastaName.replace(".fasta", "")

#============================================================================================================
# Process 'SNP_CNV_v1.txt' file to determine read count average.
#------------------------------------------------------------------------------------------------------------
with open(logName, "a") as myfile:
	myfile.write("\n\t\t\t|\tProcessing dataset 'SNP_CNV_v1.txt' file -> max and average read counts per fragment.\n")

# Look up chromosome name strings for genome in use.
#     Read in and parse : "links_dir/main_script_dir/genome_specific/[genome]/figure_definitions.txt"
# Example lines in figureDefinition_file:
#     Chr  Use   Label   Name                         posX   posY   width   height
#     1    1     Chr1    Ca21chr1_C_albicans_SC5314   0.15   0.8    0.8     0.0625
#     2    1     Chr2    Ca21chr2_C_albicans_SC5314   0.15   0.7    *       0.0625
#     0    0     Mito    Ca19-mtDNA                   0.0    0.0    0.0     0.0
figureDefinition_file  = genomeDirectory + 'figure_definitions.txt'
figureDefinitionFile   = open(figureDefinition_file,'r')
figureDefinitionData   = figureDefinitionFile.readlines()
with open(logName, "a") as myfile:
	myfile.write("\t\t\t|\tDetermining number of chromosomes of interest in genome.\n")
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
chrSize = []
chrData = []
for x in range(0, chrName_maxcount):
	chrName.append([])
	chrSize.append(0)
	chrData.append([])

with open(logName, "a") as myfile:
	myfile.write("\t\t\t|\tGathering name strings for chromosomes.\n")

# Gather name strings for chromosomes, in order.
figureDefinitionFile  = open(figureDefinition_file,'r')
chrCounter = 0
chrNums    = []
chrNames   = []
chrLabels  = []
chrShorts  = []
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
				myfile.write("\t\t\t|\t" + str(chr_num) + " : " + chr_name + " = " + chr_nameShort + "\n")
figureDefinitionFile.close()

chrSize_file  = genomeDirectory + 'chromosome_sizes.txt'
chrSizesFile  = open(chrSize_file,'r')
chrSizesData  = chrSizesFile.readlines()
chrSizes      = []
with open(logName, "a") as myfile:
	myfile.write("\t\t\t|\tDetermining sizes of chromosomes in genome.\n")
for line in chrSizesData:
	line_parts = string.split(string.strip(line))
	chr_num = line_parts[0]
	if chr_num.isdigit():
		chr_num    = int(float(line_parts[0]))
		chr_size   = int(float(line_parts[1]))
		chrSize [int(float(chr_num))-1] = chr_size
		with open(logName, "a") as myfile:
			myfile.write("\t\t\t|\t" + str(chr_num) + " : " + chrName[int(float(chr_num))-1] + " size = " + chr_size + "\n")
chrSizesFile.close()

# Put the chromosome count into a smaller name for later use.
chrCount = chrName_maxcount
with open(logName, "a") as myfile:
	myfile.write("\t\t\t|\tMax chr string : "+str(chrCount)+"\n")

count            = 0
old_chr          = 0
fragment_found   = 0
last_fragment    = 0
current_fragment = 0
log_count        = 0
log_offset       = 0

print '### Number of Chromosomes = ' + str(chrCount)
for x in range(0,chrCount):
	if (chrNums[x] != 0):
		print '### \t' + str(x+1) + ' : ' + str(chrName[x]) + ' (' + str(chrSize[x]) + 'bp)'

with open(logName, "a") as myfile:
	myfile.write("\t\t\t|\tGathering read coverage data for each fragment.\n\t\t\t|")

#............................................................................................................

with open(logName, "a") as myfile:
	myfile.write("\t\t\t|\tOpen dataset 'SNP_CNV_v1.txt' file.\n")

# Open dataset 'SNP_CNV_v1.txt' file.
print '### InputFile = ' + inputFile
datafile      = inputFile;
data          = open(datafile,'r')
# Process 'SNP_CNV_v1.txt' file, line by line.
for line in data:
	# example lines from CNV pileup file:
	#     chromosomeNam                 pos             totalReads        0
	#     Ca21chr1_C_albicans_SC5314    2388924         123               0
	#     Ca21chr1_C_albicans_SC5314    2388925         135               0
	count += 1
	line_parts = string.split(string.strip(line))
	chr_name   = line_parts[0]   # chr name of bp.		: Ca21chrR_C_albicans_SC5314
	position   = line_parts[1]   # chr position of bp.	: 2286371
	readCount  = line_parts[2]   # read count at bp.	: 12

	# Identify which chromosome this data point corresponds to.
	chr = 0
	for x in range(0,chrCount):
		#if (chrNums[x] != 0):
			#	print str(chrName[x])
		if (chrNums[x] != 0):
			if chrName[x] == chr_name:
				chr = x+1

	# Convert to integers.
	pos_point  = int(position)
	data_point = float(readCount)

	if old_chr != chr:
		print '### chr change : ' + str(old_chr) + ' -> ' + str(chr)
		with open(logName, "a") as myfile:
			myfile.write("\n\t\t\t|\n\t\t\t|\t" + str(old_chr) + " -> " + str(chr) + " = " + chr_name + "\n")
			myfile.write("\t\t\t|\t1........01........01........01........01........01........01........01........01........01........0\n")

	if chr!=0:
		# Reset for each new chromosome examined.
		if old_chr != chr:
			if log_offset != 0:
				log_offset_string = " "*((log_offset)%100)
				with open(logName, "a") as myfile:
					myfile.write("\t\t\t|\t" + log_offset_string)

		# Adds current score to chr count : chrData[chr_num] += readSum
		chrData[chr-1][3] += data_point

	# Reset old_chr to current coordinate chromosome before moving to next line in pileup. 
	old_chr       = chr
	last_fragment = current_fragment
data.close()

with open(logName, "a") as myfile:
	myfile.write("\n\t\t\t|\tCalculating average read coverage per fragment.\n")

genome_length = 0
genome_reads  = 0
# Calculate average read coverage.
for chr in range(0,chrCount):
	if (chrNums[x] != 0):
		genome_length += chrSize[chr-1]
		genome_reads  += chrData[chr-1]
genome_average = genome_reads/float(genome_length)
#------------------------------------------------------------------------------------------------------------
# End of code section to parse read average.
#============================================================================================================


# # Variables defining CNV peaks to find.
# sizeMin    = 100
# sizeMax    = 15000
# minDiff    = 1.5




print "### ", time.clock() - t1, "seconds to process the pileup file."
t2 = time.clock()
print '### Number of fragments = ' + str(numFragments)
print '### Data from each fragment: [chrNum, bpStart, bpEnd, aveDepth]'

#============================================================================================================
# Code section to output information about read average per standard bin genome fragment.
#------------------------------------------------------------------------------------------------------------
with open(logName, "a") as myfile:
	myfile.write("\t\t\t|\tOutput condensed CNV per fragment information.\n")
for fragment in range(1,numFragments):
	# Output a line for each fragment.
	#     fragments[fragment-1] = [chr_num,bp_start,bp_end, aveDepth]
	#     0) chr_num
	#     1) bp_start
	#     2) bp_end
	#     3) average reads
	chr_num         = fragments[fragment-1][0]
	bp_start        = fragments[fragment-1][1]
	bp_end          = fragments[fragment-1][2]
	read_average    = fragments[fragment-1][5]
	print str(chr_num) + '\t' + str(bp_start) + '\t' + str(bp_end) + '\t' + str(read_average)
#------------------------------------------------------------------------------------------------------------
# End of code section to output information about fragments. 
#============================================================================================================


print "### ", time.clock() - t1, "seconds to output basic stats of each restriction fragment."
print "### ", time.clock() - t0, "seconds to complete processing of fragment definitions."

with open(logName, "a") as myfile:
	myfile.write("\t\t\t|\tTime to process = " + str(time.clock()-t0) +"\n")
	myfile.write("\t\t\t|\t'py/dataset_process_for_CNV_analysis.py' completed.\n")
	myfile.write("\t\t\t*----------------------------------------------------------------*\n")
	myfile.write("\t\t\t| End of Log from 'dataset_process_for_CNV_analysis.py'          |\n")
	myfile.write("\t\t\t*================================================================*\n")