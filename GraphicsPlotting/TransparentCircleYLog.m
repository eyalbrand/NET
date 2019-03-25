%  h=TransparentCircleYLog(X,Y,R,C,transparency,NPoints,varargin)
% Function purpose : Plots transparant line by drawing a rectangular patch on LogScale
%
% Function recives :   X - x coordinate of circle center
%                      Y - coordinate of circle center
%                      R - Radius of circle (R can be entered as a two coordinates to [R(1) R(2)] for aspect ratio different than 1:1.
%                      C-color of line (either 'r' or [0.1 0.4 0.7])
%                      transparency - a number between [0 1] indicating the transparency of the line
%                      NPoints - the number of points in the circle(default = 36)
%                      varargin - other arguments of the patch.
%
% Function give back :  h - circle patch handle
%
% Last updated : 07/12/09
function h=TransparentCircleYLog(X,Y,R,C,transparency,NPoints,varargin)

if nargin<6
    NPoints=36;
end
if length(R)==1 %in case only one R is entered
    R(2)=R(1);
end
angleP=0:(360/NPoints):180;
angleN=180:(360/NPoints):360;
PX=X+R(1)*cos([angleP angleN]*pi/180);
PY=Y+[10.^(R(2)*sin(angleP*pi/180)) -10.^(R(2)*sin(angleP*pi/180))];
h=patch(PX,PY,C,'EdgeColor','none','FaceAlpha',transparency,varargin{:});