function [newX, newY] = optimize_mylowess(rawData_X,rawData_Y, numFits)

numDat        = length(rawData_X);
spans         = linspace(0.01,0.99, numFits);
sse           = zeros(size(spans));
cp            = cvpartition(numDat,'k',10);
X             = rawData_X';
Y             = rawData_Y';

LOWESS_method = 3;

if (LOWESS_method == 1)
	% Attempts LOWESS fitting with [numFits] smoothing values evenly spaced from 0.01 to 0.99.
	sse  = zeros(size(spans));
	fprintf(['\t\tSquared-error minimization:\n']);
	for j = 1:numFits
		fprintf(['\t\t\tFit type0 #' num2str(j) '/' num2str(numFits) '.\t[']);
		f      = @(train,test) norm(test(:,2) - mylowess(train,test(:,1),spans(j)))^2;
		fprintf(':');
		sse(j) = sum(crossval(f,[X,Y],'partition',cp));
		fprintf(['](error = ' num2str(sse(j)) ')\n']);
	end;
elseif (LOWESS_method == 2)
	% Attempts LOWESS fitting with [numFits] smoothing values evenly spaced from 0.01 to 0.99.
	sse  = zeros(size(spans));
	fprintf(['\t\tSquared-error minimization:\n']);
	for j = 1:numFits
		fprintf(['\t\t\tFit type1 #' num2str(j) '/' num2str(numFits) '.\t[']);
		% perform LOWESS fitting with current span.
		arrayDim = size(X);
		if (arrayDim(1) > arrayDim(2))
			Ys  = mylowess([X, Y],X,spans(j));
		else
			Ys  = mylowess([X', Y'],X,spans(j));
		end;
		fprintf(':');
		% determine error between LOWESS fit and dataset.
		LSerrorSum  = 0;
		LSerrorSum2 = 0;
		for i = 1:length(Y)
			LSerrorSum  = LSerrorSum  + (Y(i)-Ys(i))^2;
		end;
		sse(j)  = LSerrorSum;
		fprintf(['](error = ' num2str(sse(j)) ')\n']);
	end;
elseif (LOWESS_method == 3)
	% Attempts LOWESS fitting with [numFits] smoothing values evenly spaced from 0.01 to 0.99, using 10-fold cross-validation of randomly partitioned data.
	fprintf(['\t\t10-fold cross validation, with squared-error minimization:\n']);
	for j = 1:numFits
		fprintf(['\t\t\tFit type2 #' num2str(j) '/' num2str(numFits) '.\t[']);
		% Randomly sort the input data into 10 partitions.
		randIndex      = randperm(length(rawData_X));      % random order of length the length of the data.
		partitionDataX = cell(1,10);
		partitionDataY = cell(1,10);
		partitionIndex = 1;
		for i = 1:length(rawData_X);
			partitionDataX{partitionIndex} = [partitionDataX{partitionIndex} rawData_X(i)];
			partitionDataY{partitionIndex} = [partitionDataY{partitionIndex} rawData_Y(i)];
			partitionIndex                 = partitionIndex+1;
			if (partitionIndex == 11);
				partitionIndex = 1;
			end;
		end;
		fprintf(':');
		LSerrorSum  = 0;
		for partitionIndex = 1:10
			OtherX = [];
			OtherY = [];
			for i = 1:10
				if (i ~= partitionIndex)
					OtherX = [OtherX partitionDataX{partitionIndex}];
					OtherY = [OtherY partitionDataY{partitionIndex}];
				end;
			end;
			ThisX   = partitionDataX{partitionIndex};
			ThisY   = partitionDataY{partitionIndex};
			arrayDim = size(OtherX);
			if (arrayDim(1) > arrayDim(2))
				ThisYs  = mylowess([OtherX, OtherY],ThisX,spans(j));
			else
				ThisYs  = mylowess([OtherX', OtherY'],ThisX,spans(j));
			end;
			% determine cumulative error between LOWESS fit and dataset.
			for i = 1:length(ThisX)
				LSerrorSum  = LSerrorSum  + (ThisY(i)-ThisYs(i))^2;
			end;
		end;
		sse(j) = LSerrorSum;
		fprintf(['](error = ' num2str(sse(j)) ')\n']);
	end;
end;


% Find the smoothing value which produces the least error between the LOWESS fit and the raw data.
[minsse,minj] = min(sse);
span          = spans(minj);
range_length  = 400;
X_range       = linspace(min(X),max(X),range_length);

newX = X_range;
if ((LOWESS_method == 1) || (LOWESS_method == 2))
	% Generate final fit from LOWESS (on all data) with found best span.
	newY = mylowess([X,Y],X_range,span);
elseif (LOWESS_method == 3)
	% Generate final fit as average of fits from LOWESS (on k-fold training subsets) with found best span.
	%    This final fit better represents the relationship captured in the cumulative error term for the
	%    10-fold cross validation.
	newY = zeros(1,range_length);
	for partitionIndex = 1:10
		OtherX = [];
		OtherY = [];
		for i = 1:10
			if (i ~= partitionIndex)
				OtherX = [OtherX partitionDataX{partitionIndex}];
				OtherY = [OtherY partitionDataY{partitionIndex}];
			end;
		end;
		arrayDim = size(OtherX);
		if (arrayDim(1) > arrayDim(2))
			newY_part = mylowess([OtherX, OtherY],X_range,spans(j));
		else
			newY_part = mylowess([OtherX', OtherY'],X_range,spans(j));
		end;
		newY = newY+newY_part;
	end;
	newY = newY/10;
end;

end
