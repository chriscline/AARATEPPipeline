function values = c_convertValuesFromUnitToUnit(values,fromUnit,toUnit)
% c_convertValuesFromUnitToUnit - Convert values between units (e.g. mm to m)
% Can handle {km,m,cm,mm,um,pm,miles,feet}, {kV,V,mV,uV,pV,dBmV,dBuV}, or arbitrary relative scales
%
% Syntax:
%   convertedValues = c_convertValuesFromUnitToUnit(values,fromUnit,toUnit)
%
% Inputs:
%    values - scalar or vector/matrix of numeric values to convert
%    fromUnit - current unit of input values
%    toUnit - desired output unit of convertedValues
%
% Outputs:
%    convertedValues
%
% Examples: 
%   c_convertValuesFromUnitToUnit(0.123,'m','mm')
%   c_convertValuesFromUnitToUnit(0.123,'m','ft')
%   c_convertValuesFromUnitToUnit([1 2 3],'mV','uV')
%	c_convertValuesFromUnitToUnit(0.123,1,0.001)

	assert(isnumeric(values));
	
	if ~(ischar(fromUnit) || isscalar(fromUnit)) || ~(ischar(toUnit) || isscalar(toUnit))
		error('Unsupported unit type(s)');
	end
	
	if isequal(fromUnit,toUnit)
		% do not change values
		return;
	end
	
	if ~ischar(fromUnit) && isnan(fromUnit) && ~ischar(toUnit) && isnan(toUnit)
		% do not change values
		return;
	end
	
	if (~ischar(fromUnit) && isnan(fromUnit)) || (~ischar(toUnit) && isnan(toUnit))
		warning('Cannot convert units from %s to %s; returning unchanged values.',fromUnit,toUnit);
		return;
	end
	
	nonScalarUnits = {'dBmV','dBuV','unitless_amplitude','unitless_power','dB'};
	if (~isscalar(fromUnit) && ismember(fromUnit,nonScalarUnits)) || (~isscalar(toUnit) && ismember(toUnit,nonScalarUnits))
		% handle unit conversions such as fahrenheit to celsius that are not just a scale factor
		switch(toUnit)
			case 'dBmV'
				values = c_convertValuesFromUnitToUnit(values,fromUnit,'mV');
				values = 20*log10(values);
			case 'dBuV'
				values = c_convertValuesFromUnitToUnit(values,fromUnit,'uV');
				values = 20*log10(values);
			case 'dB'
				switch(fromUnit)
					case 'unitless_amplitude' % i.e. amplitude ratio
						values = 20*log10(values);
					case 'unitless_power' % i.e. power ratio
						values = 10*log10(values);
					otherwise
						error('Cannot convert from %s to %s',fromUnit,toUnit);
				end
			case 'unitless_amplitude'
				switch(fromUnit)
					case 'dB'
						values = 10.^(values/20);
					otherwise
						error('Cannot convert from %s to %s',fromUnit,toUnit);
				end
			case 'unitless_power'
				switch(fromUnit)
					case 'dB'
						values = 10.^(values/10);
					otherwise
						error('Cannot convert from %s to %s',fromUnit,toUnit);
				end
			otherwise
				switch(fromUnit)
					case 'dBmV'
						values = 10.^(values/20);
						values = c_convertValuesFromUnitToUnit(values,'mV',toUnit);
					case 'dBuV'
						values = 10.^(values/20);
						values = c_convertValuesFromUnitToUnit(values,'uV',toUnit);
					otherwise
						error('Cannot convert from %s to %s',fromUnit,toUnit);
				end
		end
		return;
	end
	
	fromType = '';
	if ischar(fromUnit)
		[fromUnit, fromType] = strUnitAsNumUnit(fromUnit);
	end
	
	toType = '';
	if ischar(toUnit)
		[toUnit, toType] = strUnitAsNumUnit(toUnit);
	end
	
	% prevent attempts at conversion between, for example, voltage and distance
	if ~isempty(fromType) && ~isempty(toType) && ~strcmpi(fromType,toType)
		error('Converting from type %s to type %s not supported',fromType, toType);
	end
	
	scaleFactor = fromUnit/toUnit;
	
	if isnan(scaleFactor)
		% do not change values
		return;
	end
	
	values = values*scaleFactor;	
end

function [numUnit, unitType] = strUnitAsNumUnit(strUnit)
	if ~isempty(strUnit)
		if length(strUnit)==1
			strPrefix = '';
			strSuffix = strUnit;
		else
			strPrefix = strUnit(1);
			strSuffix = strUnit(2:end);
		end
		isMetric = true;
		switch(strSuffix)
			case 'm'
				unitType = 'distance';
			case 'V'
				unitType = 'voltage';
			case 's'
				unitType = 'time';
			case 'A-m'
				unitType = 'current-distance';
			otherwise
				isMetric = false;
				unitType = ''; % unrecognized
		end
		
		if isMetric
			% unit is supported in SI format
			if isempty(strPrefix)
				% e.g. 'm' or 'V' without prefix
				numUnit = 1;
				return;
			else
				% try as SI (prefix)(suffix) format, e.g. 'km'
				numUnit = nan;
				switch(strPrefix)
					case 'k'
						numUnit = 1e3;
					case 'd'
						numUnit = 1e-1;
					case 'c'
						numUnit = 1e-2;
					case 'm'
						numUnit = 1e-3;
					case 'u'
						numUnit = 1e-6;
					case 'n'
						numUnit = 1e-9;
					case 'p'
						numUnit = 1e-12;
				end
				if ~isnan(numUnit)
					return;
				end
			end
		end
	end
	
	switch(strUnit)
		case 'miles'
			numUnit = 1609.344;
			unitType = 'distance';
		case {'feet','ft'}
			numUnit = 0.3048;
			unitType = 'distance';
		case {'min','minutes'}
			numUnit = 60;
			unitType = 'time';
		case {'sec','seconds'}
			numUnit = 1;
			unitType = 'time';
		case {'rad','radians'}
			numUnit = 1;
			unitType = 'angle';
		case {'deg','degrees','°'}
			numUnit = pi/180;
			unitType = 'angle';
		otherwise
			error('Unsupported unit: %s',strUnit);
	end
end