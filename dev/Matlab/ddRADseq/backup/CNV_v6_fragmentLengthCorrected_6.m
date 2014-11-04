function [] = CNV_v6_fragmentLengthCorrected_6(main_dir,user,genome,genomeUser,project,parentProject,parentUser,ploidyEstimate,ploidyBase, ...
                                 CNV_verString,displayBREAKS);
%% ========================================================================
% Generate CGH-type figures from RADseq data, using a reference dataset to correct for genome position-dependant biases.
%==========================================================================
Centromere_format_default   = 0;
Yscale_nearest_even_ploidy  = true;
HistPlot                    = true;
ChrNum                      = true;
show_annotations            = true;
Linear_display              = true;
Low_quality_ploidy_estimate = true;


%%=========================================================================
% Load FASTA file name from 'reference.txt' file for project.
%--------------------------------------------------------------------------
Reference    = [main_dir 'users/' genomeUser '/genomes/' genome '/reference.txt'];
FASTA_string = strtrim(fileread(Reference));
[FastaPath,FastaName,FastaExt] = fileparts(FASTA_string);


%%=========================================================================
% Control variables.
%--------------------------------------------------------------------------
projectDir = [main_dir 'users/' user       '/projects/' project '/'];
parentDir  = [main_dir 'users/' parentUser '/projects/' parentProject '/'];
genomeDir  = [main_dir 'users/' genomeUser '/genomes/'  genome '/'];

fprintf(['\n### projectDir : ' projectDir '\n']);
fprintf([  '### parentDir  : ' parentDir  '\n']);
fprintf([  '### genomeDir  : ' genomeDir  '\n']);
fprintf([  '### genome     : ' genome     '\n']);
fprintf([  '### project    : ' project    '\n']);
[centromeres, chr_sizes, figure_details, annotations, ploidy_default] = Load_genome_information_1(main_dir,genomeDir,genome);
[Aneuploidy] = [];

if (strcmp(project,parentProject) == 1)
	ParentValid = 0;
else
	ParentValid = 1;
end;

for i = 1:length(chr_sizes)
	chr_size(chr_sizes(i).chr)    = chr_sizes(i).size;
end;
for i = 1:length(centromeres)
	cen_start(centromeres(i).chr) = centromeres(i).start;
	cen_end(centromeres(i).chr)   = centromeres(i).end;
end;
if (length(annotations) > 0)
	for i = 1:length(annotations)
		annotation_chr(i)       = annotations(i).chr;
		annotation_type{i}      = annotations(i).type;
		annotation_start(i)     = annotations(i).start;
		annotation_end(i)       = annotations(i).end;
		annotation_fillcolor{i} = annotations(i).fillcolor;
		annotation_edgecolor{i} = annotations(i).edgecolor;
		annotation_size(i)      = annotations(i).size;
	end;
end;
for i = 1:length(figure_details)
	if (figure_details(i).chr == 0)
		key_posX   = figure_details(i).posX;
		key_posY   = figure_details(i).posY;
		key_width  = figure_details(i).width;
		key_height = figure_details(i).height;
	else
		chr_id    (figure_details(i).chr) = figure_details(i).chr;
		chr_label {figure_details(i).chr} = figure_details(i).label;
		chr_name  {figure_details(i).chr} = figure_details(i).name;
		chr_posX  (figure_details(i).chr) = figure_details(i).posX;
		chr_posY  (figure_details(i).chr) = figure_details(i).posY;
		chr_width (figure_details(i).chr) = figure_details(i).width;
		chr_height(figure_details(i).chr) = figure_details(i).height;
		chr_in_use(figure_details(i).chr) = str2num(figure_details(i).useChr);
	end;
end;
num_chrs      = length(chr_size);


%%=========================================================================
%%= No further control variables below. ===================================
%%=========================================================================

% Sanitize user input of euploid state.
ploidyBase = round(str2num(ploidyBase));
if (ploidyBase > 4);   ploidyBase = 4;   end;
if (ploidyBase < 1);   ploidyBase = 1;   end;
fprintf(['\nEuploid base = "' num2str(ploidyBase) '"\n']);

% basic plot parameters not defined per genome.
TickSize         = -0.005;  %negative for outside, percentage of longest chr figure.
bases_per_bin    = max(chr_size)/700;
maxY             = ploidyBase*2;
cen_tel_Xindent  = 5;
cen_tel_Yindent  = maxY/5;

%% Determine reference genome FASTA file in use.
%  Read in and parse : "links_dir/main_script_dir/genome_specific/[genome]/reference.txt"
reference_file   = [main_dir 'users/' genomeUser '/genomes/' genome '/reference.txt'];
refernce_fid     = fopen(reference_file, 'r');
refFASTA         = fgetl(refernce_fid);
fclose(refernce_fid);


%%================================================================================================
% Load pre-processed ddRADseq fragment CNV data for project.
%-------------------------------------------------------------------------------------------------
if (exist([main_dir 'users/' user '/projects/' project '/fragment_CNV_data.mat'],'file') == 0)
    %  Including : [chrNum, bpStart, bpEnd, maxReads, AveReads, fragmentLength]
    %	1	9638	10115	2	0	478
    %	1	10116	10123	2	1	8
    %	1	13170	13841	0	0	672
    fprintf('Loading results from Python script, which pre-processed the dataset relative to genome restriction fragments : project\n');
    datafile_RADseq  = [main_dir 'users/' user '/projects/' project '/preprocessed_CNVs.ddRADseq.txt'];
    data_RADseq      = fopen(datafile_RADseq);
    count            = 0;
    fragments_CNV    = [];
    while ~feof(data_RADseq)
		% Load fragment data from pre-processed text file, single line.
		dataLine = fgetl(data_RADseq);
		if (length(dataLine) > 0)
			if (dataLine(1) ~= '#')   % If the first space-delimited string is not '#', then process it as a valid data line.
			    % The number of valid lines found so far...  the number of usable restriction fragments with data so far.
			    count = count + 1;

			    % Each valid data line consists of four tab-delimited collumns : [chrNum, bpStart, bpEnd, Ave_reads]
				chr_num         = str2num(sscanf(dataLine, '%s',1));
				bp_start        = sscanf(dataLine, '%s',  2 );    for i = 1:size(sscanf(dataLine,'%s', 1 ),2);   bp_start(1)  = [];   end;   bp_start  = str2num(bp_start);
				bp_end          = sscanf(dataLine, '%s',  3 );    for i = 1:size(sscanf(dataLine,'%s', 2 ),2);   bp_end(1)    = [];   end;   bp_end    = str2num(bp_end);
				ave_reads       = sscanf(dataLine, '%s',  4 );    for i = 1:size(sscanf(dataLine,'%s', 3 ),2);   ave_reads(1) = [];   end;   ave_reads = str2num(ave_reads);
				fragment_length = bp_end - bp_start + 1;

			    % Add fragment data to data structure.
			    fragments_CNV(count).chr        = chr_num;
			    fragments_CNV(count).startbp    = bp_start;
			    fragments_CNV(count).endbp      = bp_end;
			    fragments_CNV(count).length     = fragment_length;
			    fragments_CNV(count).ave_reads  = ave_reads;
			    fragments_CNV(count).usable     = 1;
			end;
		end;
	end;
	fclose(data_RADseq);
	save([main_dir 'users/' user '/projects/' project '/fragment_CNV_data.mat'], 'fragments_CNV');
else
	load([main_dir 'users/' user '/projects/' project '/fragment_CNV_data.mat']);
end;
project_fragments_CNV = fragments_CNV;
clear fragments_CNV;


%%================================================================================================
% Load pre-processed ddRADseq fragment CNV data for parent project.
%-------------------------------------------------------------------------------------------------
if (strcmp(project,parentProject) == 1)
	parent_fragments_CNV = project_fragments_CNV;
else
	load([main_dir 'users/' parentUser '/projects/' parentProject '/fragment_CNV_data.mat']);
	parent_fragments_CNV = fragments_CNV;
	clear fragments_CNV;
end;


%%================================================================================================
% Load pre-processed ddRADseq fragment GC-bias data for genome.
%-------------------------------------------------------------------------------------------------
fprintf(['standard_bins_GC_ratios_file :\n\t' main_dir 'users/' genomeUser '/genomes/' genome '/' FastaName '.GC_ratios.MfeI_MboI.txt\n']);
GC_ratios_fid = fopen([main_dir 'users/' genomeUser '/genomes/' genome '/' FastaName '.GC_ratios.MfeI_MboI.txt'], 'r');
fprintf(['\t' num2str(GC_ratios_fid) '\n']);
fragID = 0;
while not (feof(GC_ratios_fid))
	dataLine = fgetl(GC_ratios_fid);
	if (length(dataLine) > 0)
		if (dataLine(1) ~= '#')
			% The number of valid lines found so far...  the number of usable restriction fragments with data so far.
			fragID              = fragID + 1;
			chr                 = str2num(sscanf(dataLine, '%s',1));
			fragment_start      = sscanf(dataLine, '%s',2);  for i = 1:size(sscanf(dataLine,'%s',1),2);      fragment_start(1) = []; end;    fragment_start = str2num(fragment_start);
			fragment_end        = sscanf(dataLine, '%s',3);  for i = 1:size(sscanf(dataLine,'%s',2),2);      fragment_end(1)   = []; end;    fragment_end   = str2num(fragment_end);
			GCratio             = sscanf(dataLine, '%s',4);  for i = 1:size(sscanf(dataLine,'%s',3),2);      GCratio(1)        = []; end;    GCratio        = str2num(GCratio);
			GCratioData(fragID) = GCratio;
		end;
	end;
end;
fclose(GC_ratios_fid);


%%================================================================================================
% Add reference depth and GC-bias data to common data structure : 'fragment_data'
%-------------------------------------------------------------------------------------------------
fragment_data = project_fragments_CNV;
numFragments  = length(fragment_data);
for fragID = 1:numFragments
	% Add parent read depth to common data structure.
	fragment_data(fragID).ave_reads_parent = parent_fragments_CNV(fragID).ave_reads;

	% Add GCratio data to common data structure.
	fragment_data(fragID).GC_bias  = GCratioData(fragID);

	% Initialize all data as being usable.
	fragment_data(fragID).usable = 1;
	fragment_data(fragID).usable_parent = 1;
end;


%%================================================================================================
% Determine which fragments have usable data.
%-------------------------------------------------------------------------------------------------
fprintf('Gathering [fragment length], [CNV], & [GC bias] data for plotting bias and correction.\n');
for fragID = 1:numFragments
	if ((fragment_data(fragID).length == 0) || (fragment_data(fragID).ave_reads == 0) || (fragment_data(fragID).ave_reads_parent == 0))
		fragment_data(fragID).usable = 0;
		fragment_data(fragID).usable_parent = 0;
	end;
end;


%% ===============================================================================================
% Construct figures illustrating LOWESS fitting and normalization.
%-------------------------------------------------------------------------------------------------
fprintf('Generating figure with plot of length vs. coverage data.\n');
fig = figure(1);
% subplot handle list.
sh=zeros(11,1);


%% ****************************************************************************************************************************************************************************
% *****************************************************************************************************************************************************************************
% *****************************************************************************************************************************************************************************


%% ===============================================================================================
% Prepare for LOWESS fitting 1 : correcting fragment_length bias.
%-------------------------------------------------------------------------------------------------
fprintf('\tPreparing for LOWESS fitting 1 : fragment length vs. average read depth.\n');
X_length                    = zeros(1,numFragments);
Y_reads_project             = zeros(1,numFragments);
Y_reads_parent              = zeros(1,numFragments);
for fragID = 1:numFragments
	X_length(fragID)        = fragment_data(fragID).length; 
	Y_reads_project(fragID) = fragment_data(fragID).ave_reads;
	Y_reads_parent(fragID)  = fragment_data(fragID).ave_reads_parent;
end;
X_length_trimmed            = X_length;
Y_reads_project_trimmed     = Y_reads_project;
Y_reads_parent_trimmed      = Y_reads_parent;
%------------------------------------------------------------*
% Trim dataset before LOWESS fitting 1.                      |
%------------------------------------------------------------*
	% Remove fragments longer than 1000bp.
	Y_reads_project_trimmed( X_length_trimmed > 1000) = [];
	Y_reads_parent_trimmed(  X_length_trimmed > 1000) = [];
	X_length_trimmed(        X_length_trimmed > 1000) = [];
%------------------------------------------------------------*
%	% Remove fragments with less than 1.5 average reads in project.
%	Y_reads_parent_trimmed(  Y_reads_project_trimmed < 1.5) = [];
%	X_length_trimmed(        Y_reads_project_trimmed < 1.5) = [];
%	Y_reads_project_trimmed( Y_reads_project_trimmed < 1.5) = [];
%------------------------------------------------------------*
%	% Remove fragments with less than 1.5 average reads in parent.
%	X_length_trimmed(        Y_reads_parent_trimmed < 1.5) = [];
%	Y_reads_project_trimmed( Y_reads_parent_trimmed < 1.5) = [];
%	Y_reads_parent_trimmed(  Y_reads_parent_trimmed < 1.5) = [];
%------------------------------------------------------------*

%-------------------------------------------------------------------------------------------------
% LOWESS fitting project 1 : correcting fragment_length bias.
%-------------------------------------------------------------------------------------------------
% Perform LOWESS fitting.
fprintf('Subplot 1/11 : [EXPERIMENT] (Ave read depth) vs. (Fragment length).\n');
sh(1) = subplot(5,4,[1 2]);
fprintf('\tLOWESS fitting to trimmed project data.\n');
[newX1_project, newY1_project]      = optimize_mylowess(          X_length_trimmed,Y_reads_project_trimmed,10);

% [TGF_X1, TGF1_Y1, TGF1_Y2, TGF1_Y3] = optimize_mylowess_2gaussian(X_length_trimmed,Y_reads_project_trimmed,10, 4*max(newY1_project));

fprintf('\tLOWESS fitting to project data complete.\n');
% Calculate length_bia_corrected ave_read_count data for plotting and later analysis.
Y_target                    = 1;
Y_fitCurve1_project         = interp1(newX1_project,newY1_project,X_length,'spline');
Y_reads_project_corrected_1 = Y_reads_project./Y_fitCurve1_project*Y_target;
%-------------------------------------------------------------------------------------------------
% Plotting raw average read depth vs. fragment length for project.
%-------------------------------------------------------------------------------------------------
plot(X_length,Y_reads_project,'.', 'color', [0.0, 0.66667, 0.33333], 'MarkerSize', 1);
hold on;
plot(newX1_project, newY1_project,'color','k','linestyle','-', 'linewidth',1);
% plot(TGF_X1, TGF1_Y1,'color','r','linestyle','-', 'linewidth',1);
% plot(TGF_X1, TGF1_Y2,'color','g','linestyle','-', 'linewidth',1);
% plot(TGF_X1, TGF1_Y3,'color','b','linestyle','-', 'linewidth',1);
hold off;
axis normal;
h = title('Examine bias between ddRADseq fragment length and read count. [EXP]');   set(h, 'FontSize', 10);
h = ylabel('Average Reads');     set(h, 'FontSize', 10);
h = xlabel('Fragment Length');   set(h, 'FontSize', 10);
set(gca,'FontSize',10);
ylim([1 4*max(newY1_project)]);
xlim([0 1000]);

if (ParentValid == 1)
	%-------------------------------------------------------------------------------------------------
	% LOWESS fitting parent 1 : correcting fragment_length bias.
	%-------------------------------------------------------------------------------------------------
	%% Perform LOWESS fitting.
	fprintf('Subplot 2/11 : [REFERENCE] (Ave read count) vs. (Fragment length).\n');
	sh(2) = subplot(5,4,[3 4]);
	fprintf('\tLOWESS fitting to reference data.\n');
	[newX1_parent, newY1_parent] = optimize_mylowess(X_length_trimmed,Y_reads_parent_trimmed,10);
	fprintf('\tLOWESS fitting to referemce data complete.\n');
	% Calculate length_bia_corrected ave_read_count data for plotting and later analysis.
	Y_target                   = 1;
	Y_fitCurve1_parent         = interp1(newX1_parent,newY1_parent,X_length,'spline');
	Y_reads_parent_corrected_1 = Y_reads_parent./Y_fitCurve1_parent*Y_target;
	%-------------------------------------------------------------------------------------------------
	% Plotting raw average read depth vs. fragment length for parent.
	%-------------------------------------------------------------------------------------------------
	plot(X_length,Y_reads_parent,'.', 'color', [0.0, 0.66667, 0.33333], 'MarkerSize', 1);
	hold on;
	plot(newX1_parent, newY1_parent,'color','k','linestyle','-', 'linewidth',1);
	hold off;
	axis normal;
	h = title('Examine bias between ddRADseq fragment length and read count. [REF]');   set(h, 'FontSize', 10);
	h = ylabel('Average Reads');     set(h, 'FontSize', 10);
	h = xlabel('Fragment Length');   set(h, 'FontSize', 10);
	set(gca,'FontSize',10);
	ylim([1 4*max(newY1_parent)]);
	xlim([0 1000]);
end;

%-------------------------------------------------------------------------------------------------
% Plotting length-bias corrected read depth vs. fragment length for project.
%-------------------------------------------------------------------------------------------------
fprintf('Subplot 3/11 : [EXPERIMENT] (Ave read count, with bias corrected) vs. (Fragment length).\n');
sh(3) = subplot(5,4,[5 6]);
hold on;
for fragID = 1:numFragments
	% Add corrected ave_data to fragment data structure.
	fragment_data(fragID).ave_reads_corrected_1 = Y_reads_project_corrected_1(fragID);

	% Define data as no useful if correction fit term falls below 5 reads.
	if (Y_fitCurve1_project(fragID)         <= 1   );   fragment_data(fragID).usable = 0;   end;
%	if (Y_reads_project(fragID)             <= 1.5 );   fragment_data(fragID).usable = 0;   end;
	if (Y_reads_project_corrected_1(fragID) <= 0   );   fragment_data(fragID).usable = 0;   end;
	if (X_length(fragID)                    <  50  );   fragment_data(fragID).usable = 0;   end;
	if (X_length(fragID)                    >  1000);   fragment_data(fragID).usable = 0;   end;

	% Plot each corrected data point, colored depending on if data is useful or not.
	X_datum = fragment_data(fragID).length;                  % X_Length
	Y_datum = fragment_data(fragID).ave_reads_corrected_1;   % Y_reads_corrected_1
	if (fragment_data(fragID).usable == 1)
		plot(X_datum,Y_datum,'.', 'color', [0.0, 0.66667, 0.33333], 'MarkerSize',0.2);
	else
		plot(X_datum,Y_datum,'.', 'color', [1.0, 0.0, 0.0], 'MarkerSize',0.2);
	end;

	if (mod(fragID,1000) == 0)
		fprintf('.');
	end;
end;
fprintf('\n');
plot(newX1_project,Y_target,'color','k','linestyle','-', 'linewidth',1);
hold off;
axis normal;
h = title('Corrected Read count vs. ddRADseq fragment length. [EXPERIMENT]');   set(h, 'FontSize', 10);
h = ylabel('Corrected Reads');   set(h, 'FontSize', 10);
h = xlabel('Fragment Length');   set(h, 'FontSize', 10);
set(gca,'FontSize',10);
ylim([0 4]);
xlim([1 1000]);

if (ParentValid == 1)
	%-------------------------------------------------------------------------------------------------
	% Plotting corrected read depth vs. fragment length for parent.
	%-------------------------------------------------------------------------------------------------
	fprintf('Subplot 4/11 : [REFERENCE] (Ave read count, with bias corrected) vs. (Fragment length).\n');
	sh(4) = subplot(5,4,[7 8]);
	hold on;
	Y_target = 1;
	% Calculate bias_corrected ave_read_copy data for plotting and later analysis.
	Y_fitCurve1_parent         = interp1(newX1_parent,newY1_parent,X_length,'spline');   
	Y_reads_parent_corrected_1 = Y_reads_parent./Y_fitCurve1_parent*Y_target;
	fprintf(['\tlength(Y_fitCurve1_parent)         = ' num2str(length(Y_fitCurve1_parent))         '\n']);
	fprintf(['\tlength(Y_reads_parent_corrected_1) = ' num2str(length(Y_reads_parent_corrected_1)) '\n']);
	fprintf('\t');
	for fragID = 1:numFragments
		% Add corrected ave_data to fragment data structure.
		fragment_data(fragID).ave_reads_parent_corrected_1 = Y_reads_parent_corrected_1(fragID);

		% Define data as not useful if correction fit term falls below 5 reads.
		fragment_data(fragID).usable_parent = 1;
		if (Y_fitCurve1_parent(fragID)         <= 1   );   fragment_data(fragID).usable_parent = 0;   end;
%		if (Y_reads_parent(fragID)             <= 1.5 );   fragment_data(fragID).usable_parent = 0;   end;
		if (Y_reads_parent_corrected_1(fragID) <= 0   );   fragment_data(fragID).usable_parent = 0;   end;
		if (X_length(fragID)                   <  50  );   fragment_data(fragID).usable_parent = 0;   end;
		if (X_length(fragID)                   >  1000);   fragment_data(fragID).usable_parent = 0;   end;

		% Plot each corrected data point, colored depending on if data is useful or not.
		X_datum = fragment_data(fragID).length;                         % X_Length
		Y_datum = fragment_data(fragID).ave_reads_parent_corrected_1;   % Y_reads_parent_corrected_1
		if (fragment_data(fragID).usable_parent == 1)
			plot(X_datum,Y_datum,'.', 'color', [0.0, 0.66667, 0.33333], 'MarkerSize',0.2);
		else
			plot(X_datum,Y_datum,'.', 'color', [1.0, 0.0, 0.0], 'MarkerSize',0.2);
		end;

		if (mod(fragID,1000) == 0)
			fprintf('.');
		end;
	end;
	fprintf('\n');
	plot(newX1_parent,Y_target,'color','k','linestyle','-', 'linewidth',1);
	hold off;
	axis normal;
	h = title('Corrected Read count vs. ddRADseq fragment length. [REFERENCE]');   set(h, 'FontSize', 10);
	h = ylabel('Corrected Reads');   set(h, 'FontSize', 10);
	h = xlabel('Fragment Length');   set(h, 'FontSize', 10);
	set(gca,'FontSize',10);
	ylim([0 4]);
	xlim([1 1000]);
end;


%% ****************************************************************************************************************************************************************************
% *****************************************************************************************************************************************************************************
% *****************************************************************************************************************************************************************************


%%================================================================================================
% Prepare for LOWESS fitting 2
%-------------------------------------------------------------------------------------------------
fprintf('\tPreparing for LOWESS fitting 2 : GC_ratio vs. corrected_count_1.\n');
X_GCbias_project = zeros(1,numFragments);
Y_reads_project  = zeros(1,numFragments);
usable_project   = zeros(1,numFragments);
if (ParentValid == 1)
	X_GCbias_parent  = zeros(1,numFragments);
	Y_reads_parent   = zeros(1,numFragments);
	usable_parent    = zeros(1,numFragments);
end;
for fragID = 1:numFragments
	X_GCbias_project(fragID) = fragment_data(fragID).GC_bias;
	Y_reads_project(fragID)  = fragment_data(fragID).ave_reads_corrected_1;
	usable_project(fragID)   = fragment_data(fragID).usable;
	if (ParentValid == 1)
		X_GCbias_parent(fragID)  = fragment_data(fragID).GC_bias;
		Y_reads_parent(fragID)   = fragment_data(fragID).ave_reads_parent_corrected_1;
		usable_parent(fragID)    = fragment_data(fragID).usable_parent;
	end;
end;
X_GCbias_project_trimmed = X_GCbias_project;
Y_reads_project_trimmed  = Y_reads_project;
if (ParentValid == 1)
	X_GCbias_parent_trimmed  = X_GCbias_parent;
	Y_reads_parent_trimmed   = Y_reads_parent;
end;
%------------------------------------------------------------*
% Trim dataset before LOWESS fitting 2.                      |
%------------------------------------------------------------*
	X_GCbias_project_trimmed(usable_project == 0) = [];
	Y_reads_project_trimmed( usable_project == 0) = [];
	if (ParentValid == 1)
		X_GCbias_parent_trimmed( usable_parent  == 0) = [];
		Y_reads_parent_trimmed(  usable_parent  == 0) = [];
	end;
%------------------------------------------------------------*

%-------------------------------------------------------------------------------------------------
% LOWESS fitting project 2.
%-------------------------------------------------------------------------------------------------
% Perform LOWESS fitting.
fprintf('\tLOWESS fitting to project data.\n');
[newX2_project, newY2_project] = optimize_mylowess(X_GCbias_project_trimmed,Y_reads_project_trimmed,10);
fprintf('\tLOWESS fitting to project data complete.\n');
% Calculate GC_bias_corrected length_bia_corrected ave_read_count data for plotting and later analysis.
Y_target                    = 1;
Y_fitCurve2_project         = interp1(newX2_project,newY2_project,X_GCbias_project,'spline');
Y_reads_project_corrected_2 = Y_reads_project./Y_fitCurve2_project*Y_target;
%-------------------------------------------------------------------------------------------------
% Show GC bias vs. corrected_1 read depth for project.
%-------------------------------------------------------------------------------------------------
fprintf('Subplot 5/11 : [EXP] (Corrected reads 1) vs. (Fragment GC ratio).\n');
sh(5) = subplot(5,4,9);
hold on;
for fragID = 1:numFragments
	if (fragment_data(fragID).usable == 1)
		if (fragment_data(fragID).ave_reads_corrected_1 < Y_fitCurve2_project(fragID))
			plot(fragment_data(fragID).GC_bias,fragment_data(fragID).ave_reads_corrected_1,'.', 'color', [0.0, 0.66667, 0.33333], 'MarkerSize',1);
		else
			plot(fragment_data(fragID).GC_bias,fragment_data(fragID).ave_reads_corrected_1,'.', 'color', [0.0, 0.45, 0.55], 'MarkerSize',1);
		end;
	end;
end;
plot(newX2_project,newY2_project,'color','k','linestyle','-', 'linewidth',1);
hold off;
axis normal;
h = title('GC ratio vs. Corrected reads 1. [EXP]');   set(h, 'FontSize', 10);
h = ylabel('Corrected reads 1');  set(h, 'FontSize', 10);
h = xlabel('GC ratio');           set(h, 'FontSize', 10);
set(gca,'FontSize',10);
xlim([0 1]);
ylim([0 4]);

if (ParentValid == 1)
	%-------------------------------------------------------------------------------------------------
	% LOWESS fitting parent 2.
	%-------------------------------------------------------------------------------------------------
	% Perform LOWESS fitting.
	fprintf('\tLOWESS fitting to parent data.\n');
	[newX2_parent, newY2_parent] = optimize_mylowess(X_GCbias_parent_trimmed,Y_reads_parent_trimmed,10);
	fprintf('\tLOWESS fitting to parent data complete.\n');
	% Calculate GC_bias_corrected length_bia_corrected ave_read_count data for plotting and later analysis.
	Y_target                   = 1;
	Y_fitCurve2_parent         = interp1(newX2_parent,newY2_parent,X_GCbias_parent,'spline');
	Y_reads_parent_corrected_2 = Y_reads_parent./Y_fitCurve2_parent*Y_target;
	%-------------------------------------------------------------------------------------------------
	% Show GC bias vs. corrected_1 read depth for parent.
	%-------------------------------------------------------------------------------------------------
	fprintf('Subplot 6/11 : [REF] (Corrected reads 1) vs. (Fragment GC ratio).\n');
	sh(7) = subplot(5,4,11);
	hold on;
	for fragID = 1:numFragments
		if (fragment_data(fragID).usable == 1)
			if (fragment_data(fragID).ave_reads_parent_corrected_1 < Y_fitCurve2_parent(fragID))
				plot(fragment_data(fragID).GC_bias,fragment_data(fragID).ave_reads_parent_corrected_1,'.', 'color', [0.0, 0.66667, 0.33333], 'MarkerSize',1);
			else
				plot(fragment_data(fragID).GC_bias,fragment_data(fragID).ave_reads_parent_corrected_1,'.', 'color', [0.0, 0.45, 0.55], 'MarkerSize',1);
			end;
		end;
	end;
	plot(newX2_parent,newY2_parent,'color','k','linestyle','-', 'linewidth',1);
	hold off;
	axis normal;
	h = title('GC ratio vs. Corrected reads 1. [REF]');   set(h, 'FontSize', 10);
	h = ylabel('Corrected reads 1');  set(h, 'FontSize', 10);
	h = xlabel('GC ratio');           set(h, 'FontSize', 10);
	set(gca,'FontSize',10);
	xlim([0 1]);
	ylim([0 4]);
end;

%-------------------------------------------------------------------------------------------------
% Plotting length-bias corrected read depth vs. fragment length for project.
%-------------------------------------------------------------------------------------------------
fprintf('Subplot 7/11 : [EXP] (Corrected reads 2) vs. (Fragment GC ratio).\n');
sh(6) = subplot(5,4,10);
hold on;
for fragID = 1:numFragments
	% Add corrected ave_data to fragment data structure.
	fragment_data(fragID).ave_reads_corrected_2 = Y_reads_project_corrected_2(fragID);

	% Plot each corrected data point, colored depending on if data is useful or not.
	X_datum = fragment_data(fragID).GC_bias;                 % X_GCbias
	Y_datum = fragment_data(fragID).ave_reads_corrected_2;   % Y_reads_corrected_2
	if (fragment_data(fragID).usable == 1)
		plot(X_datum,Y_datum,'.', 'color', [0.0, 0.66667, 0.33333], 'MarkerSize',0.2);
	else
		plot(X_datum,Y_datum,'.', 'color', [1.0, 0.0, 0.0], 'MarkerSize',0.2);
	end;

	if (mod(fragID,1000) == 0)
		fprintf('.');
	end;
end;
fprintf('\n');
plot(newX2_project,Y_target,'color','k','linestyle','-', 'linewidth',1);
hold off;
axis normal;
h = title('GC ratio bias corrected. [EXPERIMENT]');   set(h, 'FontSize', 10);
h = ylabel('Corrected Reads 2');   set(h, 'FontSize', 10);
h = xlabel('GC ratio');            set(h, 'FontSize', 10);
set(gca,'FontSize',10);
xlim([0 1]);
ylim([0 4]);

if (ParentValid == 1)
	%-------------------------------------------------------------------------------------------------
	% Plotting length-bias corrected read depth vs. fragment length for parent.
	%-------------------------------------------------------------------------------------------------
	fprintf('Subplot 8/11 : [REF] (Corrected reads 2) vs. (Fragment GC ratio).\n');
	sh(8) = subplot(5,4,12);
	hold on;
	for fragID = 1:numFragments
		% Add corrected ave_data to fragment data structure.
		fragment_data(fragID).ave_reads_parent_corrected_2 = Y_reads_parent_corrected_2(fragID);

		% Plot each corrected data point, colored depending on if data is useful or not.
		X_datum = fragment_data(fragID).GC_bias;                        % X_GCbias
		Y_datum = fragment_data(fragID).ave_reads_parent_corrected_2;   % Y_reads_parent_corrected_2
		if (fragment_data(fragID).usable == 1)
			plot(X_datum,Y_datum,'.', 'color', [0.0, 0.66667, 0.33333], 'MarkerSize',0.2);
		else
			plot(X_datum,Y_datum,'.', 'color', [1.0, 0.0, 0.0], 'MarkerSize',0.2);
		end;

		if (mod(fragID,1000) == 0)
			fprintf('.');
		end;
	end;
	fprintf('\n');
	plot(newX2_parent,Y_target,'color','k','linestyle','-', 'linewidth',1);
	hold off;
	axis normal;
	h = title('GC ratio bias corrected. [REF]');   set(h, 'FontSize', 10);
	h = ylabel('Corrected Reads 2');               set(h, 'FontSize', 10);
	h = xlabel('GC ratio');                        set(h, 'FontSize', 10);
	set(gca,'FontSize',10);
	xlim([0 1]);
	ylim([0 4]);
end;

%-------------------------------------------------------------------------------------------------
% Show corrected_2 read depth vs. length for project.
%-------------------------------------------------------------------------------------------------
fprintf('Subplot 9/11 : [EXP] (Corrected reads 3) vs. (Fragment length).\n');
sh(9) = subplot(5,4,[13 14]);
hold on;
for fragID = 1:numFragments
	% Plot each corrected data point, colored depending on if data is useful or not.
	X_datum = fragment_data(fragID).length;
	Y_datum = fragment_data(fragID).ave_reads_corrected_2;
	if (fragment_data(fragID).usable == 1)
		plot(X_datum,Y_datum,'.', 'color', [0.0, 0.66667, 0.33333], 'MarkerSize',1);
	else
		plot(X_datum,Y_datum,'.', 'color', [1.0, 0.0, 0.0], 'MarkerSize',1);
	end;
end;
plot(newX2_project,1,'color','k','linestyle','-', 'linewidth',1);
hold off;
axis normal;
h = title('Corrected Read count vs. ddRADseq fragment length. [EXP]');   set(h, 'FontSize', 10);
h = ylabel('Corrected reads');   set(h, 'FontSize', 10);
h = xlabel('Fragment Length');   set(h, 'FontSize', 10);
set(gca,'FontSize',10);
ylim([0 4]);
xlim([1 1000]);

if (ParentValid == 1)
	%-------------------------------------------------------------------------------------------------
	% Show corrected_2 read depth vs. length for parent.
	%-------------------------------------------------------------------------------------------------
	fprintf('Subplot 10/10 : [REF] (Corrected reads 3) vs. (Fragment length).\n');
	sh(10) = subplot(5,4,[15 16]);
	hold on;
	for fragID = 1:numFragments
		% Plot each corrected data point, colored depending on if data is useful or not.
		X_datum = fragment_data(fragID).length;
		Y_datum = fragment_data(fragID).ave_reads_parent_corrected_2;
		if (fragment_data(fragID).usable == 1)
			plot(X_datum,Y_datum,'.', 'color', [0.0, 0.66667, 0.33333], 'MarkerSize',1);
		else
			plot(X_datum,Y_datum,'.', 'color', [1.0, 0.0, 0.0], 'MarkerSize',1);
		end;
	end;
	plot(newX2_parent,1,'color','k','linestyle','-', 'linewidth',1);
	hold off;
	axis normal;
	h = title('Corrected_2 reads count vs. ddRADseq fragment length. [REF]');   set(h, 'FontSize', 10);
	h = ylabel('Corrected reads');   set(h, 'FontSize', 10);
	h = xlabel('Fragment Length');   set(h, 'FontSize', 10);
	set(gca,'FontSize',10);
	ylim([0 4]);
	xlim([1 1000]);
end;

%-------------------------------------------------------------------------------------------------
% Final subfigure showing corrected project data divided by corrected parent data.
%-------------------------------------------------------------------------------------------------
fprintf('Subplot 11/11 : [REF] (Corrected reads 3) vs. (Fragment length).\n');
sh(11) = subplot(5,4,[18 19]);
hold on;
finalFrag_data     = zeros(1,numFragments);
finalFrag_tracking = ones(1,numFragments);
for fragID = 1:numFragments
	if (ParentValid == 1)
		if ((Y_reads_project_corrected_2(fragID) == 0) || (Y_reads_parent_corrected_2(fragID) == 0))
			finalFrag_tracking(fragID) = 0;
		end;
		Y_datum_final              = Y_reads_project_corrected_2(fragID)/Y_reads_parent_corrected_2(fragID);
		finalFrag_data(fragID)     = Y_datum_final;
	else
		Y_datum_final              = Y_reads_project_corrected_2(fragID);
		finalFrag_data(fragID)     = Y_datum_final;
		finalFrag_tracking(fragID) = 2;
	end;

	% Plot each corrected data point, colored depending on if data is useful or not.
	X_datum = fragment_data(fragID).length;
	Y_datum = Y_datum_final;
	if ((fragment_data(fragID).usable == 1) && (fragment_data(fragID).usable_parent == 1))
		plot(X_datum,Y_datum,'.', 'color', [0.0, 0.66667, 0.33333], 'MarkerSize',1);
	elseif ((fragment_data(fragID).usable == 1) && (fragment_data(fragID).usable_parent == 0))
		plot(X_datum,Y_datum,'.', 'color', [1.0, 0.5, 0.0], 'MarkerSize',1);
		finalFrag_tracking(fragID) = 0;
	elseif ((fragment_data(fragID).usable == 0) && (fragment_data(fragID).usable_parent == 1))
		plot(X_datum,Y_datum,'.', 'color', [1.0, 0.0, 0.5], 'MarkerSize',1);
		finalFrag_tracking(fragID) = 0;
	else
		plot(X_datum,Y_datum,'.', 'color', [1.0, 0.0, 0.0], 'MarkerSize',1);
		finalFrag_tracking(fragID) = 0;
	end;
end;
hold off;
axis normal;
h = title('Final Corrected Read count vs. ddRADseq fragment length.');   set(h, 'FontSize', 10);
h = ylabel('Corrected reads');   set(h, 'FontSize', 10);
h = xlabel('Fragment Length');   set(h, 'FontSize', 10);
set(gca,'FontSize',10);
ylim([0 4]);
xlim([1 1000]);


% Calculate median of final project:parent ratio data per fragment.
% testData1                               = finalFrag_data
finalFrag_data(finalFrag_tracking == 0) = [];
% testData2                               = finalFrag_data
finalFrag_median                          = median(finalFrag_data);
fprintf(['\n***\n*** median CNV value of fragments = ' num2str(finalFrag_median) '\n***\n\n']);


%%================================================================================================
% Load 'preprocessed_SNPs.ddRADseq.txt' file for CNV_filtering, then output to 'preprocessed_SNPs.ddRADseq.CNV_filtered.txt'
%.................................................................................................
% SNP data from CNV filtered fragments is discarded.
%-------------------------------------------------------------------------------------------------
datafile = [projectDir 'preprocessed_SNPs.ddRADseq.txt'];

location = pwd;

fprintf( '***\n');
fprintf(['*** current dir = "' location '"\n']); 
fprintf(['*** datafile    = "' datafile '"\n']);
fprintf( '***\n');

[data,fopen_message] = fopen(datafile, 'r')

fragment_count = 0;
fragment_entry = [];
while not (feof(data))
	dataLine = fgetl(data);
	if (length(dataLine) > 0)
		if (dataLine(1) ~= '#')
			% process the loaded line into data channels.
			fragment_count                 = fragment_count+1;
			fragment_entry{fragment_count} = dataLine;
		end;
	end;
end;
fclose(data);
% darrenabbey : removed filtering, as it removed too much data.
%for i = length(fragment_entry):-1:1
%	if (finalFrag_tracking(i) == 0)
%		fragment_entry{i} = [];
%	end;
%end;
datafile = [projectDir 'preprocessed_SNPs.ddRADseq.CNV_filtered.txt'];
data     = fopen(datafile, 'w');
for i = 1:length(fragment_entry)
	fprintf(data,[fragment_entry{i} '\n']);
end;


%% ****************************************************************************************************************************************************************************
% *****************************************************************************************************************************************************************************
% *****************************************************************************************************************************************************************************


%-------------------------------------------------------------------------------------------------
% Saving figure.
%-------------------------------------------------------------------------------------------------
fprintf('Saving figure.\n');
set(fig,'PaperPosition',[0 0 8 6]*4);
saveas(fig, [main_dir 'users/' user '/projects/' project '/fig.examine_bias.eps'], 'epsc');
saveas(fig, [main_dir 'users/' user '/projects/' project '/fig.examine_bias.png'], 'png');
delete(fig);

%
%%
%%%
%%%%
%%%%
%%%%
%%%
%%
%

%% Save fragment_data for project again, now that we've assigned usable vs. not usable.
fragments_CNV = fragment_data;
save([main_dir 'users/' user '/projects/' project '/fragment_CNV_data.mat'], 'fragments_CNV');


%%=========================================================================
%%= Analyze corrected CNV data for RADseq datasets. =======================
%%=========================================================================
fprintf(['\nGenerating CNV figure from ''' project ''' sequence data corrected by removing restriction fragment length bias.\n']);
% Initializes vectors used to hold copy number data.
for chr = 1:num_chrs   % number of chrs.
	if (chr_in_use(chr) == 1)
		% 4 categories tracked :
		%	project : total read counts in bin.
		%	project : number of data entries in region (size of bin in base-pairs).
		%	parent  : total read counts in bin.
		%	parent  : number of data entries in region (size of bin in base-pairs).
		chr_CNVdata_RADseq{chr,1} = zeros(1,ceil(chr_size(chr)/bases_per_bin));
		chr_CNVdata_RADseq{chr,2} = zeros(1,ceil(chr_size(chr)/bases_per_bin));
		chr_CNVdata_RADseq{chr,3} = zeros(1,ceil(chr_size(chr)/bases_per_bin));
		chr_CNVdata_RADseq{chr,4} = zeros(1,ceil(chr_size(chr)/bases_per_bin));
	end;
end;
% Output chromosome lengths to log file.
for i = 1:length(chr_name)
	fprintf(['\nchr' num2str(i) ' = ''' chr_name{i} '''.\tCGHlength = ' num2str(length(chr_CNVdata_RADseq{i,1}))]);
end;


%-------------------------------------------------------------------------------------------------
% Choose which data level to display.
%-------------------------------------------------------------------------------------------------
% Abbey
%	0 :  : raw data.
%	1 :  : raw data, normalized vs. fragment_length.
%	2 :  : raw data, normalized vs. fragment_length, normalized vs. GCbias.
DataDisplayLevel = 2;
fprintf(['\n\n@#$\n@#$ Data display level = ' num2str(DataDisplayLevel) '\n@#$\n']);
%   project/parent ratio is calculated after standard_bin values are calculated.


%-------------------------------------------------------------------------------------------------
% Distribute project and parent data into standard bins, then save as 'corrected_CNV.project.mat'.
%-------------------------------------------------------------------------------------------------
if (exist([main_dir 'users/' user '/projects/' project '/corrected_CNV.project.mat'],'file') == 0)
	fprintf('\nMAT file containing project CNV information not found, regenerating from prior data files.\n');
	% Convert bias corrected ave_copy_number per restriction digest fragment into CNV data for plotting
	fprintf('\n# Adding fragment corrected_ave_read_copy values to map bins.');
	for fragID = 1:numFragments
		if ((fragment_data(fragID).usable == 1) && (fragment_data(fragID).usable_parent == 1))
			% Load important data from fragments data structure.
			chr        = fragment_data(fragID).chr;
			posStart   = fragment_data(fragID).startbp;
			posEnd     = fragment_data(fragID).endbp;
			fragLength = fragment_data(fragID).length;

			if (DataDisplayLevel == 0)
				count1 = fragment_data(fragID).ave_reads;                          % project : raw data.
				if (ParentValid == 1)
					count2 = fragment_data(fragID).ave_reads_parent;               % parent  : raw data.
				else
					count2 = 1;
				end;
			elseif (DataDisplayLevel == 1)
				count1 = fragment_data(fragID).ave_reads_corrected_1;              % project : normalized vs. fragment_length.
				if (ParentValid == 1)
					count2 = fragment_data(fragID).ave_reads_parent_corrected_1;   % parent  : normalized vs. fragment_length.
				else
					count2 = 1;
				end;
			elseif (DataDisplayLevel == 2)
				count1 = fragment_data(fragID).ave_reads_corrected_2;              % project : normalized vs. fragment_length, normalized vs. GCbias.
				if (ParentValid == 1)
					count2 = fragment_data(fragID).ave_reads_parent_corrected_2;   % parent  : normalized vs. fragment_length, normalized vs. GCbias.
				else
					count2 = 1;
				end;
			elseif (DataDisplayLevel == 3)
				count1 = fragment_data(fragID).ave_reads_corrected_3;              % project : normalized vs. fragment_length, normalized vs. GCbias, smoothed.
				if (ParentValid == 1)
					count2 = fragment_data(fragID).ave_reads_parent_corrected_3;   % parent  : normalized vs. fragment_length, normalized vs. GCbias, smoothed.
				else
					count2 = 1;
				end;
			else
				count1 = 1;                                                        % project : error state.
				count2 = 1;                                                        % parent  : error state.
			end;

			% Identify locations of fragment end in relation to plotting bins.
			val1 = ceil(posStart/bases_per_bin);
			val2 = ceil(posEnd  /bases_per_bin);

			%
			% Dividing the first CNV data channel by 'finalFrag_median' normalizes the final per-fragment CNV value by the median of
			% the final per-fragment CNV values.   This should correct the final CNV artifact found in the ddRADseq data from AForche
			% caused by zero:noise fragment data points.
			%

			if (chr > 0) && (count1 > 0) && (count2 > 0)
				% 'count' is average read count across fragment, so it will need multiplied by fragment length (or fraction) before
				%     adding to each bin.
				if (val1 == val2)
					% All of the restriction fragment belongs to one bin.
					if (val1 <= length(chr_CNVdata_RADseq{chr,1}))
						% project standard_bins data.
						% chr_CNVdata_RADseq{chr,1}(val1) = chr_CNVdata_RADseq{chr,1}(val1) + count1*fragLength;
						chr_CNVdata_RADseq{chr,1}(val1) = chr_CNVdata_RADseq{chr,1}(val1) + count1*fragLength/finalFrag_median;
						chr_CNVdata_RADseq{chr,2}(val1) = chr_CNVdata_RADseq{chr,2}(val1) + fragLength;
						% parent standard_bins data.
						chr_CNVdata_RADseq{chr,3}(val1) = chr_CNVdata_RADseq{chr,3}(val1) + count2*fragLength;
						chr_CNVdata_RADseq{chr,4}(val1) = chr_CNVdata_RADseq{chr,4}(val1) + fragLength;
					end;
				else % (val1 < val2)
					% The restriction fragment belongs partially to two bins, so we must determine fraction assigned to each bin.
					posEdge     = val1*bases_per_bin;
					fragLength1 = posEdge-posStart+1;
					fragLength2 = posEnd-posEdge;

					% Add data to first bin.
					if (val1 <= length(chr_CNVdata_RADseq{chr,1}))
						% project standard_bins data.
						% chr_CNVdata_RADseq{chr,1}(val1) = chr_CNVdata_RADseq{chr,1}(val1) + count1*fragLength1;
						chr_CNVdata_RADseq{chr,1}(val1) = chr_CNVdata_RADseq{chr,1}(val1) + count1*fragLength1/finalFrag_median;
						chr_CNVdata_RADseq{chr,2}(val1) = chr_CNVdata_RADseq{chr,2}(val1) + fragLength1;
						% parent standard_bins data.
						chr_CNVdata_RADseq{chr,3}(val1) = chr_CNVdata_RADseq{chr,3}(val1) + count2*fragLength1;
						chr_CNVdata_RADseq{chr,4}(val1) = chr_CNVdata_RADseq{chr,4}(val1) + fragLength1;
					end;

					% Add data to second bin.
					if (val2 <= length(chr_CNVdata_RADseq{chr,1}))
						% project standard_bins data.
						% chr_CNVdata_RADseq{chr,1}(val2) = chr_CNVdata_RADseq{chr,1}(val2) + count1*fragLength2;
						chr_CNVdata_RADseq{chr,1}(val2) = chr_CNVdata_RADseq{chr,1}(val2) + count1*fragLength2/finalFrag_median;
						chr_CNVdata_RADseq{chr,2}(val2) = chr_CNVdata_RADseq{chr,2}(val2) + fragLength2;
						% parent standard_bins data.
						chr_CNVdata_RADseq{chr,3}(val2) = chr_CNVdata_RADseq{chr,3}(val2) + count2*fragLength2;
						chr_CNVdata_RADseq{chr,4}(val2) = chr_CNVdata_RADseq{chr,4}(val2) + fragLength2;
					end;
				end;
			end;
		end;
	end;
	fprintf('\n# Fragment corrected_ave_read_copy values have been added to map bins.');

	save([main_dir 'users/' user '/projects/' project '/corrected_CNV.project.mat'],'chr_CNVdata_RADseq');
else
	fprintf('\nProject CNV MAT file found, loading.\n');
	load([main_dir 'users/' user '/projects/' project '/corrected_CNV.project.mat']);
end;
% chr_CNVdata_RADseq;


%%================================================================================================
% Smooth CNV standard_bin values for project and parent separately.  abbeyabbey
%.................................................................................................
% Left-end bin:
%     (33.333% bin-1) + (66.667% bin)
% Middle bins:
%     (25% bin-1) + (50% bin) + (25% bin+1)
% Right-end bin:
%     (66.667% bin) + (33.333% bin+1)
%-------------------------------------------------------------------------------------------------
for chr = 1:num_chrs
	if (chr_in_use(chr) == 1)
		% project standard_bins data : chr_CNVdata_RADseq{chr,1}(pos)
		% parent standard_bins data  : chr_CNVdata_RADseq{chr,3}(pos)

		%% Left-end bin.
		pos                = 1;
		valueCurrent       = chr_CNVdata_RADseq{chr,1}(pos  );
		valueRight         = chr_CNVdata_RADseq{chr,1}(pos+1);
		chr_CNVdata_RADseq{chr,1}(pos) = valueCurrent*2/3       + valueRight/3;
		parentValueCurrent = chr_CNVdata_RADseq{chr,3}(pos  );
		parentValueRight   = chr_CNVdata_RADseq{chr,3}(pos+1);
		chr_CNVdata_RADseq{chr,3}(pos) = parentValueCurrent*2/3 + parentValueRight/3;

		%% Middle bins.
		for pos = 2:(length(chr_CNVdata_RADseq{chr,1})-1)
			valueLeft      = chr_CNVdata_RADseq{chr,1}(pos-1);
			valueCurrent   = chr_CNVdata_RADseq{chr,1}(pos  );
			valueRight     = chr_CNVdata_RADseq{chr,1}(pos+1);
			chr_CNVdata_RADseq{chr,1}(pos) = valueLeft/4       + valueCurrent/2       + valueRight/4;
			parentValueLeft      = chr_CNVdata_RADseq{chr,3}(pos-1);
			parentValueCurrent   = chr_CNVdata_RADseq{chr,3}(pos  );
			parentValueRight     = chr_CNVdata_RADseq{chr,3}(pos+1);
			chr_CNVdata_RADseq{chr,3}(pos) = parentValueLeft/4 + parentValueCurrent/2 + parentValueRight/4;
		end;

		%% Right-end bin.
		pos                = length(chr_CNVdata_RADseq{chr,1});
		valueRight         = chr_CNVdata_RADseq{chr,1}(pos-1);
		valueCurrent       = chr_CNVdata_RADseq{chr,1}(pos  );
		chr_CNVdata_RADseq{chr,1}(pos) = valueLeft/3       + valueCurrent*2/3;
		parentValueRight   = chr_CNVdata_RADseq{chr,3}(pos-1);
		parentValueCurrent = chr_CNVdata_RADseq{chr,3}(pos  );
		chr_CNVdata_RADseq{chr,3}(pos) = parentValueLeft/3 + parentValueCurrent*2/3;
	end;
end;

%% -----------------------------------------------------------------------------------------
% Convert 'chr_CNVdata_RADseq' to 'CNVplot2' for saving to 'Common_CNV' file and figure generation.
%-------------------------------------------------------------------------------------------
for chr = 1:num_chrs
	CNVplot2{chr}     = zeros(1,length(chr_CNVdata_RADseq{chr,1}));
	CNV_tracking{chr} = zeros(1,length(chr_CNVdata_RADseq{chr,1}));
end;
for chr = 1:num_chrs
	if (chr_in_use(chr) == 1)
		for pos = 1:length(chr_CNVdata_RADseq{chr,1})
			% Plot the sum of the data in each region, divided by the number of data points in each region; then divided by this value calculated for SC5314 data.
			if ((chr_CNVdata_RADseq{chr,2}(pos) == 0) || (chr_CNVdata_RADseq{chr,4}(pos) == 0))
				% No data elements => null value is plotted.
				CNVplot2{chr}(pos)     = 0;
			else
				% project : sum of data elements is divided by the number of data elements.
				CNVplot1a{chr}(pos)    = chr_CNVdata_RADseq{chr,1}(pos)/chr_CNVdata_RADseq{chr,2}(pos);

				% parent  : sum of data elements is divided by the number of data elements.
				CNVplot1b{chr}(pos)    = chr_CNVdata_RADseq{chr,3}(pos)/chr_CNVdata_RADseq{chr,4}(pos);

				if (ParentValid == 1)
					% divide project_standard_bin by parent_standard_bin value for final normalization.
					CNVplot2{chr}(pos) = CNVplot1a{chr}(pos)/CNVplot1b{chr}(pos);
				else
					CNVplot2{chr}(pos) = CNVplot1a{chr}(pos);
				end;
				CNV_tracking{chr}(pos) = 1;
			end;
		end;
	end;
end;


% Save presented CNV data in a file format common across data types being processed.
fprintf('\nSaving "Common_CNV" data file.');
genome_CNV = genome;
save([main_dir 'users/' user '/projects/' project '/Common_CNV.mat'], 'CNVplot2','genome_CNV');


%% -----------------------------------------------------------------------------------------
% Make figures
%-------------------------------------------------------------------------------------------
fig = figure(1);
set(gcf, 'Position', [0 70 1024 600]);

%% -----------------------------------------------------------------------------------------
% Setup for linear-view figure generation.
%-------------------------------------------------------------------------------------------
if (Linear_display == true)
	Linear_fig           = figure(2);
	Linear_genome_size   = sum(chr_size);

	Linear_Chr_max_width = 0.91;               % width for all chromosomes across figure.  1.00 - leftMargin - rightMargin - subfigure gaps.
	Linear_left_start    = 0.01;               % left margin (also right margin).
	Linear_left_chr_gap  = 0.07/(num_chrs-1);  % gaps between chr subfigures.

	Linear_height        = 0.6;
	Linear_base          = 0.1;
	Linear_TickSize      = -0.01;  %negative for outside, percentage of longest chr figure.
	maxY                 = ploidyBase*2;
	Linear_left          = Linear_left_start;
end;


%% -----------------------------------------------------------------------------------------
% Median normalize CNV data before figure generation.
%-------------------------------------------------------------------------------------------
% Gather CGH data for LOWESS fitting.
CNVdata_all      = [];
CNV_tracking_all = [];
for chr = 1:num_chrs
	if (chr_in_use(chr) == 1)
		CNVdata_all      = [CNVdata_all CNVplot2{chr}];
		CNV_tracking_all = [CNV_tracking_all CNV_tracking{chr}];
	end;
end;


% Calculate median of final CNV data per standard_bin.
% testData3                          = CNVdata_all
CNVdata_all(CNV_tracking_all == 0) = [];
% testData4                          = CNVdata_all
medianCNV                          = median(CNVdata_all);
fprintf(['\n\n***\n*** median CNV value of standard_bins = ' num2str(medianCNV) '\n***\n\n']);


for chr = 1:num_chrs
	if (chr_in_use(chr) == 1)
		CNVplot2{chr} = CNVplot2{chr}/medianCNV;
	end;
end;


ploidy = str2num(ploidyEstimate);
fprintf(['\nPloidy string = "' num2str(ploidy) '"\n']);
[chr_breaks, chrCopyNum, ploidyAdjust] = FindChrSizes_4(Aneuploidy,CNVplot2,ploidy,num_chrs,chr_in_use)
largestChr = find(chr_width == max(chr_width));


%% -----------------------------------------------------------------------------------------
% Make figures
%-------------------------------------------------------------------------------------------
first_chr = true;
for chr = 1:num_chrs
	if (chr_in_use(chr) == 1)
		figure(fig);
		% make standard chr cartoons.
		left   = chr_posX(chr);
		bottom = chr_posY(chr);
		width  = chr_width(chr);
		height = chr_height(chr);
		subplot('Position',[left bottom width height]);
		fprintf(['figposition = [' num2str(left) ' | ' num2str(bottom) ' | ' num2str(width) ' | ' num2str(height) ']\t']);
		hold on;
    
		%% cgh plot section.
		c_ = [0 0 0];
		fprintf(['chr' num2str(chr) ':' num2str(length(CNVplot2{chr})) '\n']);
		for i = 1:length(CNVplot2{chr});
			x_ = [i i i-1 i-1];
			if (CNVplot2{chr}(i) == 0)
				CNVhistValue = 1;
			else
				CNVhistValue = CNVplot2{chr}(i);
			end;

			% The CNV-histogram values were normalized to a median value of 1.
			% The ratio of 'ploidy' to 'ploidyBase' determines where the data is displayed relative to the median line.
			startY = maxY/2;
			if (Low_quality_ploidy_estimate == true)
				endY = CNVhistValue*ploidy*ploidyAdjust;
			else
				endY = CNVhistValue*ploidy;
			end;
			y_ = [startY endY endY startY];

			% makes a blackbar for each bin.
			f = fill(x_,y_,c_);
			set(f,'linestyle','none');
		end;
		x2 = chr_size(chr)/bases_per_bin;
		plot([0; x2], [maxY/2; maxY/2],'color',[0 0 0]);  % 2n line.
        
		%% draw lines across plots for easier interpretation of CNV regions.
		switch ploidyBase
			case 1
			case 2
				line([0 x2], [maxY/4*1   maxY/4*1  ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/4*3   maxY/4*3  ],'Color',[0.85 0.85 0.85]);
			case 3
				line([0 x2], [maxY/6*1   maxY/6*1  ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/6*2   maxY/6*2  ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/6*4   maxY/6*4  ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/6*5   maxY/6*5  ],'Color',[0.85 0.85 0.85]);
			case 4
				line([0 x2], [maxY/8*1   maxY/8*1  ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/8*2   maxY/8*2  ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/8*3   maxY/8*3  ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/8*5   maxY/8*5  ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/8*6   maxY/8*6  ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/8*7   maxY/8*7  ],'Color',[0.85 0.85 0.85]);
			case 5
				line([0 x2], [maxY/10*2  maxY/10*2 ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/10*4  maxY/10*4 ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/10*6  maxY/10*6 ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/10*8  maxY/10*8 ],'Color',[0.85 0.85 0.85]);
			case 6
				line([0 x2], [maxY/12*2  maxY/12*2 ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/12*4  maxY/12*4 ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/12*8  maxY/12*8 ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/12*10 maxY/12*10],'Color',[0.85 0.85 0.85]);
			case 7
				line([0 x2], [maxY/14*2  maxY/14*2 ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/14*4  maxY/14*4 ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/14*6  maxY/14*6 ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/14*8  maxY/14*8 ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/14*10 maxY/14*10],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/14*12 maxY/14*12],'Color',[0.85 0.85 0.85]);
			case 8
				line([0 x2], [maxY/16*2  maxY/16*2 ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/16*4  maxY/16*4 ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/16*6  maxY/16*6 ],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/16*10 maxY/16*10],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/16*12 maxY/16*12],'Color',[0.85 0.85 0.85]);
				line([0 x2], [maxY/16*14 maxY/16*14],'Color',[0.85 0.85 0.85]);
		end;
		%% end cgh plot section.
                    
		%axes labels etc.
		hold off;   
		xlim([0,chr_size(chr)/bases_per_bin]);
            
		%% modify y axis limits to show annotation locations if any are provided.
		if (length(annotations) > 0)
			ylim([-maxY/10*1.5,maxY]);
		else
			ylim([0,maxY]);
		end;
		set(gca,'YTick',[]);
		set(gca,'TickLength',[(TickSize*chr_size(largestChr)/chr_size(chr)) 0]); %ensures same tick size on all subfigs.

		text(-50000/5000/2*3, maxY/2,     chr_label{chr}, 'Rotation',90, 'HorizontalAlignment','center', 'VerticalAlign','bottom', 'Fontsize',20);

%		ylabel(chr_label{chr}, 'Rotation', 90, 'HorizontalAlign', 'center', 'VerticalAlign', 'bottom');
		set(gca,'XTick',0:(40*(5000/bases_per_bin)):(650*(5000/bases_per_bin)));
		set(gca,'XTickLabel',{'0.0','0.2','0.4','0.6','0.8','1.0','1.2','1.4','1.6','1.8','2.0','2.2','2.4','2.6','2.8','3.0','3.2'});
        
		% This section sets the Y-axis labelling.
		axisLabelPosition = -50000/bases_per_bin;
		switch ploidyBase
			case 1
				set(gca,'YTick',[0 maxY/2 maxY]);
				set(gca,'YTickLabel',{'','',''});
				text(axisLabelPosition, maxY/2,   '1','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY,     '2','HorizontalAlignment','right','Fontsize',10);
			case 2
				set(gca,'YTick',[0 maxY/4 maxY/2 maxY/4*3 maxY]);
				set(gca,'YTickLabel',{'','','','',''});
				text(axisLabelPosition, maxY/4,   '1','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY/2,   '2','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY/4*3, '3','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY,     '4','HorizontalAlignment','right','Fontsize',10);
			case 3
				set(gca,'YTick',[0 maxY/6 maxY/3 maxY/2 maxY/3*2 maxY/6*5 maxY]);
				set(gca,'YTickLabel',{'','','','','','',''});
				text(axisLabelPosition, maxY/2,   '3','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY,     '6','HorizontalAlignment','right','Fontsize',10);
			case 4
				set(gca,'YTick',[0 maxY/8 maxY/4 maxY/8*3 maxY/2 maxY/8*5 maxY/4*3 maxY/8*7 maxY]);
				set(gca,'YTickLabel',{'','','','','','','','',''});
				text(axisLabelPosition, maxY/4,   '2','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY/2,   '4','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY/4*3, '6','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY,     '8','HorizontalAlignment','right','Fontsize',10);
			case 5
				set(gca,'YTick',[0 maxY/10 maxY/10*2 maxY/10*3 maxY/10*4 maxY/10*5 maxY/10*6 maxY/10*7 ...
				                 maxY/10*8 maxY/10*9 maxY]);
				set(gca,'YTickLabel',{'','','','','','','','','','',''});
				text(axisLabelPosition, maxY/10*2,  '2','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY/10*5,  '5','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY/10*7,  '7','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY,       '10','HorizontalAlignment','right','Fontsize',10);
			case 6
				set(gca,'YTick',[0 maxY/12 maxY/12*2 maxY/12*3 maxY/12*4 maxY/12*5 maxY/12*6 maxY/12*7 ...
				                 maxY/12*8 maxY/12*9 maxY/12*10 maxY/12*11 maxY]);
				set(gca,'YTickLabel',{'','','','','','','','','','','','',''});
				text(axisLabelPosition, maxY/12*2,  '2','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY/12*6,  '6','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY/12*10, '10','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY,       '12','HorizontalAlignment','right','Fontsize',10);
			case 7
				set(gca,'YTick',[0 maxY/14 maxY/14*2 maxY/14*3 maxY/14*4 maxY/14*5 maxY/14*6 maxY/14*7 ...
				                 maxY/14*8 maxY/14*9 maxY/14*10 maxY/14*11 maxY/14*12 maxY/14*13 maxY]);
				set(gca,'YTickLabel',{'','','','','','','','','','','','','','',''});
				text(axisLabelPosition, maxY/14*4,  '4','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY/14*7,  '7','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY/14*11, '11','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY,       '14','HorizontalAlignment','right','Fontsize',10);
			case 8
				set(gca,'YTick',[0 maxY/16 maxY/16*2 maxY/16*3 maxY/16*4 maxY/16*5 maxY/16*6 maxY/16*7 ...
				                 maxY/16*8 maxY/16*9 maxY/16*10 maxY/16*11 maxY/16*12 maxY/16*13 maxY/16*14 maxY/16*15 maxY]);
				set(gca,'YTickLabel',{'','','','','','','','','','','','','','','','',''});
				text(axisLabelPosition, maxY/16*4,  '4' ,'HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY/16*8,  '8' ,'HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY/16*12, '12','HorizontalAlignment','right','Fontsize',10);
				text(axisLabelPosition, maxY,       '16','HorizontalAlignment','right','Fontsize',10);
		end;

		set(gca,'FontSize',12);
		if (chr == find(chr_posY == max(chr_posY)))
			title([ project ' CNV map'],'Interpreter','none','FontSize',24);
		end;
    
		hold on;
		%end axes labels etc.

		%show segmental anueploidy breakpoints.
		if (displayBREAKS == true)
			for segment = 2:length(chr_breaks{chr})-1
				bP = chr_breaks{chr}(segment)*length(CNVplot2{chr});
				c_ = [0 0 1];
				x_ = [bP bP bP-1 bP-1];
				y_ = [0 maxY maxY 0];
				f = fill(x_,y_,c_);
				set(f,'linestyle','none');
			end;
		end;
    
		%show centromere.
		if (chr_size(chr) < 100000)
			Centromere_format = 1;
		else
			Centromere_format = Centromere_format_default;
		end;
		x1 = cen_start(chr)/bases_per_bin;
		x2 = cen_end(chr)/bases_per_bin;
		leftEnd  = 0.5*(5000/bases_per_bin);
		rightEnd = chr_size(chr)/bases_per_bin-0.5*(5000/bases_per_bin);
		if (Centromere_format == 0)
			% standard chromosome cartoons in a way which will not cause segfaults when running via commandline.
			dx = cen_tel_Xindent;
			dy = cen_tel_Yindent;
			% draw white triangles at corners and centromere locations.
			fill([leftEnd   leftEnd   leftEnd+dx ],       [maxY-dy   maxY      maxY],         [1.0 1.0 1.0], 'EdgeColor',[1.0 1.0 1.0]);    % top left corner.
			fill([leftEnd   leftEnd   leftEnd+dx ],       [dy        0         0   ],         [1.0 1.0 1.0], 'EdgeColor',[1.0 1.0 1.0]);    % bottom left corner.
			fill([rightEnd  rightEnd  rightEnd-dx],       [maxY-dy   maxY      maxY],         [1.0 1.0 1.0], 'EdgeColor',[1.0 1.0 1.0]);    % top right corner.
			fill([rightEnd  rightEnd  rightEnd-dx],       [dy        0         0   ],         [1.0 1.0 1.0], 'EdgeColor',[1.0 1.0 1.0]);    % bottom right corner.
			fill([x1-dx     x1        x2           x2+dx],[maxY      maxY-dy   maxY-dy  maxY],[1.0 1.0 1.0], 'EdgeColor',[1.0 1.0 1.0]);    % top centromere.
			fill([x1-dx     x1        x2           x2+dx],[0         dy        dy       0   ],[1.0 1.0 1.0], 'EdgeColor',[1.0 1.0 1.0]);    % bottom centromere.
			% draw outlines of chromosome cartoon.   (drawn after horizontal lines to that cartoon edges are not interrupted by horiz lines.
			plot([leftEnd   leftEnd   leftEnd+dx   x1-dx   x1        x2        x2+dx   rightEnd-dx   rightEnd   rightEnd   rightEnd-dx x2+dx   x2   x1   x1-dx   leftEnd+dx   leftEnd],...
			     [dy        maxY-dy   maxY         maxY    maxY-dy   maxY-dy   maxY    maxY          maxY-dy    dy         0           0       dy   dy   0       0            dy     ],...
			      'Color',[0 0 0]);
		elseif (Centromere_format == 1)
			leftEnd  = 0;
			rightEnd = chr_size(chr)/bases_per_bin;

			% Minimal outline for examining very small sequence regions, such as C.albicans MTL locus.
			plot([leftEnd   leftEnd   rightEnd   rightEnd   leftEnd], [0   maxY   maxY   0   0], 'Color',[0 0 0]);
		end;
		%end show centromere.  
        
		%show annotation locations
		if (show_annotations) && (length(annotations) > 0)
			plot([leftEnd rightEnd], [-maxY/10*1.5 -maxY/10*1.5],'color',[0 0 0]);
			hold on;
			annotation_location = (annotation_start+annotation_end)./2;
			for i = 1:length(annotation_location)
				if (annotation_chr(i) == chr)
					annotationloc = annotation_location(i)/bases_per_bin-0.5*(5000/bases_per_bin);
					annotationStart = annotation_start(i)/bases_per_bin-0.5*(5000/bases_per_bin);
					annotationEnd   = annotation_end(i)/bases_per_bin-0.5*(5000/bases_per_bin);
					if (strcmp(annotation_type{i},'dot') == 1)
						plot(annotationloc,-maxY/10*1.5,'k:o','MarkerEdgeColor',annotation_edgecolor{i}, ...
						                                      'MarkerFaceColor',annotation_fillcolor{i}, ...
						                                      'MarkerSize',     annotation_size(i));
					elseif (strcmp(annotation_type{i},'block') == 1)
						fill([annotationStart annotationStart annotationEnd annotationEnd], ...
						     [-maxY/10*(1.5+0.75) -maxY/10*(1.5-0.75) -maxY/10*(1.5-0.75) -maxY/10*(1.5+0.75)], ...
						      annotation_fillcolor{i},'EdgeColor',annotation_edgecolor{i});
					end;
				end;
			end;
			hold off;
		end;
		%end show annotation locations.
         
		% make CGH histograms to the right of the main chr cartoons.
		if (HistPlot == true)
			width     = 0.020;
			height    = chr_height(chr);
			bottom    = chr_posY(chr);
			histAll   = [];
			histAll2  = [];
			smoothed  = [];
			smoothed2 = [];
			for segment = 1:length(chrCopyNum{chr})
				subplot('Position',[(left+chr_width(chr)+0.005)+width*(segment-1) bottom width height]);

				% The CNV-histogram values were normalized to a median value of 1.
				for i = round(1+length(CNVplot2{chr})*chr_breaks{chr}(segment)):round(length(CNVplot2{chr})*chr_breaks{chr}(segment+1))
					if (Low_quality_ploidy_estimate == true)
						histAll{segment}(i) = CNVplot2{chr}(i)*ploidy*ploidyAdjust;
					else
						histAll{segment}(i) = CNVplot2{chr}(i)*ploidy;
					end;
				end;

				% make a histogram of CGH data, then smooth it for display.
				histAll{segment}(histAll{segment}<=0)             = [];
				histAll{segment}(histAll{segment}>ploidyBase*2+2) = ploidyBase*2+2;
				histAll{segment}(length(histAll{segment})+1)      = 0;   % endpoints added to ensure histogram bounds.
				histAll{segment}(length(histAll{segment})+1)      = ploidyBase*2+2;
				smoothed{segment}    = smooth_gaussian(hist(histAll{segment},(ploidyBase*2+2)*50),5,20);
				% make a smoothed version of just the endpoints used to ensure histogram bounds.
				histAll2{segment}(1) = 0;
				histAll2{segment}(2) = ploidyBase*2+2;
				smoothed2{segment}   = smooth_gaussian(hist(histAll2{segment},(ploidyBase*2+2)*50),5,20)*4;
				% subtract the smoothed endpoints from the histogram to remove the influence of the added endpoints.
				smoothed{segment}    = (smoothed{segment}-smoothed2{segment});
				smoothed{segment}    = smoothed{segment}/max(smoothed{segment});

				hold on;
				for i = 1:(ploidyBase*2-1)
					plot([0; 1],[i*50; i*50],'color',[0.75 0.75 0.75]);
				end;
				area(smoothed{segment},(1:length(smoothed{segment}))/ploidyBase*2,'FaceColor',[0 0 0]);
				hold off;
				set(gca,'YTick',[]);
				set(gca,'XTick',[]);
				xlim([0,1]);
				ylim([0,ploidyBase*2*50]);
			end;
		end;
            
		% places chr copy number to the right of the main chr cartoons.
		if (ChrNum == true)
			% subplot to show chr copy number value.
			width  = 0.020;
			height = chr_height(chr);
			bottom = chr_posY(chr);
			if (HistPlot == true)
				subplot('Position',[(left + chr_width(chr) + 0.005 + width*(length(chrCopyNum{chr})-1) + width+0.001) bottom width height]);
			else
				subplot('Position',[(left + chr_width(chr) + 0.005) bottom width height]);
			end;
			axis off square;
			set(gca,'YTick',[]);
			set(gca,'XTick',[]);
			if (length(chrCopyNum{chr}) == 1)
				chr_string = num2str(chrCopyNum{chr}(1));
			else
				for i = 2:length(chrCopyNum{chr})
					chr_string = [chr_string ',' num2str(chrCopyNum{chr}(i))];
				end;
			end;
			text(0.1,0.5, chr_string,'HorizontalAlignment','left','VerticalAlignment','middle','FontSize',24);
		end;

        
		%% Linear figure draw section
		if (Linear_display == true)
			figure(Linear_fig);  
			Linear_width = Linear_Chr_max_width*chr_size(chr)/Linear_genome_size;
			subplot('Position',[Linear_left Linear_base Linear_width Linear_height]);
			Linear_left = Linear_left + Linear_width + Linear_left_chr_gap;
			hold on;
			title(chr_label{chr},'Interpreter','none','FontSize',20);
        
			% linear : cgh plot section.
			c_ = [0 0 0];
			fprintf(['chr' num2str(chr) ':' num2str(length(CNVplot2{chr})) '\n']);
			for i = 1:length(CNVplot2{chr});
				x_ = [i i i-1 i-1];
				if (CNVplot2{chr}(i) == 0)
					CNVhistValue = 1;
				else
					CNVhistValue = CNVplot2{chr}(i);
				end;

				% DDD
				% The CNV-histogram values were normalized to a median value of 1.
				% The ratio of 'ploidy' to 'ploidyBase' determines where the data is displayed relative to the median line.
				startY = maxY/2;
				if (Low_quality_ploidy_estimate == true)
					endY = CNVhistValue*ploidy*ploidyAdjust;
				else
					endY = CNVhistValue*ploidy;
				end;
				y_ = [startY endY endY startY];

				% makes a blackbar for each bin.
				f = fill(x_,y_,c_);
				set(f,'linestyle','none');
			end;
			x2 = chr_size(chr)/bases_per_bin;
			plot([0; x2], [maxY/2; maxY/2],'color',[0 0 0]);  % 2n line.
			% linear : end CGH plot section.

			% linear : draw lines across plots for easier interpretation of CNV regions.
			switch ploidyBase
				case 1
				case 2
					line([0 x2], [maxY/4*1   maxY/4*1  ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/4*3   maxY/4*3  ],'Color',[0.85 0.85 0.85]);
				case 3
					line([0 x2], [maxY/6*1   maxY/6*1  ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/6*2   maxY/6*2  ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/6*4   maxY/6*4  ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/6*5   maxY/6*5  ],'Color',[0.85 0.85 0.85]);
				case 4
					line([0 x2], [maxY/8*1   maxY/8*1  ],'Color',[0.85 0.85 0.85]); 
					line([0 x2], [maxY/8*2   maxY/8*2  ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/8*3   maxY/8*3  ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/8*5   maxY/8*5  ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/8*6   maxY/8*6  ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/8*7   maxY/8*7  ],'Color',[0.85 0.85 0.85]);
				case 5
					line([0 x2], [maxY/10*2  maxY/10*2 ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/10*4  maxY/10*4 ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/10*6  maxY/10*6 ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/10*8  maxY/10*8 ],'Color',[0.85 0.85 0.85]);
				case 6
					line([0 x2], [maxY/12*2  maxY/12*2 ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/12*4  maxY/12*4 ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/12*8  maxY/12*8 ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/12*10 maxY/12*10],'Color',[0.85 0.85 0.85]);
				case 7
					line([0 x2], [maxY/14*2  maxY/14*2 ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/14*4  maxY/14*4 ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/14*6  maxY/14*6 ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/14*8  maxY/14*8 ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/14*10 maxY/14*10],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/14*12 maxY/14*12],'Color',[0.85 0.85 0.85]);
				case 8
					line([0 x2], [maxY/16*2  maxY/16*2 ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/16*4  maxY/16*4 ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/16*6  maxY/16*6 ],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/16*10 maxY/16*10],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/16*12 maxY/16*12],'Color',[0.85 0.85 0.85]);
					line([0 x2], [maxY/16*14 maxY/16*14],'Color',[0.85 0.85 0.85]);
			end;
			%% linear : end cgh plot section.

			% linear : show segmental anueploidy breakpoints.
			if (displayBREAKS == true)
				for segment = 2:length(chr_breaks{chr})-1
					bP = chr_breaks{chr}(segment)*length(CNVplot2{chr});
					c_ = [0 0 1];
					x_ = [bP bP bP-1 bP-1];
					y_ = [0 maxY maxY 0];
					f = fill(x_,y_,c_);
					set(f,'linestyle','none');
				end;
			end;
			% linear : end segmental aneuploidy breakpoint section.

			% linear : show centromere.
			if (chr_size(chr) < 100000)
				Centromere_format = 1;
			else
				Centromere_format = Centromere_format_default;
			end;
			x1 = cen_start(chr)/bases_per_bin;
			x2 = cen_end(chr)/bases_per_bin;
			leftEnd  = 0.5*(5000/bases_per_bin);
			rightEnd = chr_size(chr)/bases_per_bin-0.5*(5000/bases_per_bin);
			if (Centromere_format == 0)
				% standard chromosome cartoons in a way which will not cause segfaults when running via commandline.
				dx = cen_tel_Xindent;
				dy = cen_tel_Yindent;
				% draw white triangles at corners and centromere locations.
				fill([leftEnd   leftEnd   leftEnd+dx ],       [maxY-dy   maxY      maxY],         [1.0 1.0 1.0], 'EdgeColor',[1.0 1.0 1.0]);    % top left corner.
				fill([leftEnd   leftEnd   leftEnd+dx ],       [dy        0         0   ],         [1.0 1.0 1.0], 'EdgeColor',[1.0 1.0 1.0]);    % bottom left corner.
				fill([rightEnd  rightEnd  rightEnd-dx],       [maxY-dy   maxY      maxY],         [1.0 1.0 1.0], 'EdgeColor',[1.0 1.0 1.0]);    % top right corner.
				fill([rightEnd  rightEnd  rightEnd-dx],       [dy        0         0   ],         [1.0 1.0 1.0], 'EdgeColor',[1.0 1.0 1.0]);    % bottom right corner.
				fill([x1-dx     x1        x2           x2+dx],[maxY      maxY-dy   maxY-dy  maxY],[1.0 1.0 1.0], 'EdgeColor',[1.0 1.0 1.0]);    % top centromere.
				fill([x1-dx     x1        x2           x2+dx],[0         dy        dy       0   ],[1.0 1.0 1.0], 'EdgeColor',[1.0 1.0 1.0]);    % bottom centromere.
				% draw outlines of chromosome cartoon.   (drawn after horizontal lines to that cartoon edges are not interrupted by horiz lines.
				plot([leftEnd   leftEnd   leftEnd+dx   x1-dx   x1        x2        x2+dx   rightEnd-dx   rightEnd   rightEnd   rightEnd-dx   x2+dx   x2   x1   x1-dx   leftEnd+dx  leftEnd],...
				     [dy        maxY-dy   maxY         maxY    maxY-dy   maxY-dy   maxY    maxY          maxY-dy    dy         0             0       dy   dy   0       0           dy     ],...
				     'Color',[0 0 0]);
			elseif (Centromere_format == 1)
				leftEnd  = 0;
				rightEnd = chr_size(chr)/bases_per_bin;
        
				% Minimal outline for examining very small sequence regions, such as C.albicans MTL locus.
				plot([leftEnd   leftEnd   rightEnd   rightEnd   leftEnd], [0   maxY   maxY   0   0], 'Color',[0 0 0]);
			end;
			% linear : end show centromere.
        
			% linear : show annotation locations
			if (show_annotations) && (length(annotations) > 0)
				plot([leftEnd rightEnd], [-maxY/10*1.5 -maxY/10*1.5],'color',[0 0 0]);
				hold on;
				annotation_location = (annotation_start+annotation_end)./2;
				for i = 1:length(annotation_location)
					if (annotation_chr(i) == chr)
						annotationloc = annotation_location(i)/bases_per_bin-0.5*(5000/bases_per_bin);
						annotationStart = annotation_start(i)/bases_per_bin-0.5*(5000/bases_per_bin);
						annotationEnd   = annotation_end(i)/bases_per_bin-0.5*(5000/bases_per_bin);
						if (strcmp(annotation_type{i},'dot') == 1)
							plot(annotationloc,-maxY/10*1.5,'k:o','MarkerEdgeColor',annotation_edgecolor{i}, ...
							                                      'MarkerFaceColor',annotation_fillcolor{i}, ...
							                                      'MarkerSize',     annotation_size(i));
						elseif (strcmp(annotation_type{i},'block') == 1)
							fill([annotationStart annotationStart annotationEnd annotationEnd], ...
							     [-maxY/10*(1.5+0.75) -maxY/10*(1.5-0.75) -maxY/10*(1.5-0.75) -maxY/10*(1.5+0.75)], ...
							      annotation_fillcolor{i},'EdgeColor',annotation_edgecolor{i});
						end;
					end;
				end;
				hold off;
			end;
			% linear : end show annotation locations.

			% linear :  Final formatting stuff.
			xlim([0,chr_size(chr)/bases_per_bin]);
			% modify y axis limits to show annotation locations if any are provided.
			if (length(annotations) > 0)
				ylim([-maxY/10*1.5,maxY]);
			else
				ylim([0,maxY]);
			end;
			set(gca,'TickLength',[(Linear_TickSize*chr_size(1)/chr_size(chr)) 0]); %ensures same tick size on all subfigs.
			set(gca,'XTick',0:(40*(5000/bases_per_bin)):(650*(5000/bases_per_bin)));
			set(gca,'XTickLabel',[]);
			if (first_chr)
				% This section sets the Y-axis labelling.
				axisLabelposition = -50000/bases_per_bin;
				switch ploidyBase
					case 1
						set(gca,'YTick',[0 maxY/2 maxY]);
						set(gca,'YTickLabel',{'','',''});
						text(axisLabelposition, maxY/2,   '1','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY,     '2','HorizontalAlignment','right','Fontsize',10);
					case 2
						set(gca,'YTick',[0 maxY/4 maxY/2 maxY/4*3 maxY]);
						set(gca,'YTickLabel',{'','','','',''});
						text(axisLabelposition, maxY/4,   '1','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY/2,   '2','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY/4*3, '3','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY,     '4','HorizontalAlignment','right','Fontsize',10);
					case 3
						set(gca,'YTick',[0 maxY/6 maxY/3 maxY/2 maxY/3*2 maxY/6*5 maxY]);
						set(gca,'YTickLabel',{'','','','','','',''});
						text(axisLabelposition, maxY/2,   '3','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY,     '6','HorizontalAlignment','right','Fontsize',10);
					case 4
						set(gca,'YTick',[0 maxY/8 maxY/4 maxY/8*3 maxY/2 maxY/8*5 maxY/4*3 maxY/8*7 maxY]);
						set(gca,'YTickLabel',{'','','','','','','','',''});
						text(axisLabelposition, maxY/4,   '2','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY/2,   '4','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY/4*3, '6','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY,     '8','HorizontalAlignment','right','Fontsize',10);
					case 5
						set(gca,'YTick',[0 maxY/10 maxY/10*2 maxY/10*3 maxY/10*4 maxY/10*5 maxY/10*6 maxY/10*7 ...
						                 maxY/10*8 maxY/10*9 maxY]);
						set(gca,'YTickLabel',{'','','','','','','','','','',''});
						text(axisLabelposition, maxY/10*2,  '2','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY/10*5,  '5','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY/10*7,  '7','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY,       '10','HorizontalAlignment','right','Fontsize',10);
					case 6
						set(gca,'YTick',[0 maxY/12 maxY/12*2 maxY/12*3 maxY/12*4 maxY/12*5 maxY/12*6 maxY/12*7 ...
						                 maxY/12*8 maxY/12*9 maxY/12*10 maxY/12*11 maxY]);
						set(gca,'YTickLabel',{'','','','','','','','','','','','',''});
						text(axisLabelposition, maxY/12*2,  '2','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY/12*6,  '6','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY/12*10, '10','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY,       '12','HorizontalAlignment','right','Fontsize',10);
					case 7
						set(gca,'YTick',[0 maxY/14 maxY/14*2 maxY/14*3 maxY/14*4 maxY/14*5 maxY/14*6 maxY/14*7 ...
						                 maxY/14*8 maxY/14*9 maxY/14*10 maxY/14*11 maxY/14*12 maxY/14*13 maxY]);
						set(gca,'YTickLabel',{'','','','','','','','','','','','','','',''});
						text(axisLabelposition, maxY/14*4,  '4','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY/14*7,  '7','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY/14*11, '11','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY,       '14','HorizontalAlignment','right','Fontsize',10);
					case 8
						set(gca,'YTick',[0 maxY/16 maxY/16*2 maxY/16*3 maxY/16*4 maxY/16*5 maxY/16*6 maxY/16*7 ...
						                 maxY/16*8 maxY/16*9 maxY/16*10 maxY/16*11 maxY/16*12 maxY/16*13 maxY/16*14 maxY/16*15 maxY]);
						set(gca,'YTickLabel',{'','','','','','','','','','','','','','','','',''});
						text(axisLabelposition, maxY/16*4,  '4' ,'HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY/16*8,  '8' ,'HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY/16*12, '12','HorizontalAlignment','right','Fontsize',10);
						text(axisLabelposition, maxY,       '16','HorizontalAlignment','right','Fontsize',10);
				end;
			else
				set(gca,'YTick',[]);
				set(gca,'YTickLabel',[]);
			end;
			set(gca,'FontSize',12);
			% linear : end final reformatting.
            
			% shift back to main figure generation.
			figure(fig);
			hold on;

			first_chr = false;
		end;
	end;
end;


%% ========================================================================
% end stuff
%==========================================================================

% Make figure output have transparent background.
set(gcf, 'color', 'none',...
         'inverthardcopy', 'off');
            
% Save figures.
set(fig,'PaperPosition',[0 0 8 6]*2);
saveas(fig,        [projectDir 'fig.CNV-map.1.eps'], 'epsc');
saveas(fig,        [projectDir 'fig.CNV-map.1.png'], 'png');
set(Linear_fig,'PaperPosition',[0 0 8 0.62222222]*2);
saveas(Linear_fig, [projectDir 'fig.CNV-map.2.eps'], 'epsc');
saveas(Linear_fig, [projectDir 'fig.CNV-map.2.png'], 'png');

%% Delete figures from memory.
delete(fig);
delete(Linear_fig);

end