function out = c_if(condition, valIfTrue, valIfFalse)
% c_if - evaluates condition to determine which of two values to return
% Useful for conditional statements inside anonymous functions or other shorthand conditions
%
% Example:
%	c_if(rand(1) > 0.5,'Is large','Is small')

if condition
	out = valIfTrue;
else
	out = valIfFalse;
end