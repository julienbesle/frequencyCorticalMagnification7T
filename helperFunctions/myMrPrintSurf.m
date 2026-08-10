% mrPrintSurf - print the current surface view in mrLoadRet nicely
%
%      usage: [  ] = mrPrintSurf( fName )
%         by: denis schluppeck
%       date: 2010-07-05
%        $Id: mrPrintSurf.m 1447 2015-07-27 11:22:05Z lpzjb $:
%     inputs: fName - filename for output file.
%    outputs:
%
%    purpose: pedestrian print window for surfaces that allow light and
%    material manipulations without affecting the main mrLoadRed display
%    window.
%
%        e.g:  mrPrintSurf
%              mrPrintSurf('test.tiff')
%              mrPrintSurf('test.svg')
%
% TODO -- allow user to pick resolution
%      -- get rid of color scale (via findobj and appropriate logic on handles)
%      -- optimize output options for nicest (and most consistent) printing.
%      -- color space?
%      -- add options for material properties (shiny metal dull)
%         or alternatively settings for specular, diffuse, etc. lighting.
%
function [newFig,hSurface] = myMrPrintSurf(vertices,faces,fName,el,az,edgeColor)

if ieNotDefined('fName')
    fName = [];
    % get user to specify later, when the save button is pressed
end
if ieNotDefined('az')
    az=0;
end
if ieNotDefined('el')
    el=0;
end
if ieNotDefined('edgeColor')
    edgeColor='none';
end

% % get viewnums and check that there is one!
% vnums = viewGet([],'viewnums');
% if isempty(vnums)
%     disp('(uhoh) no view open! You must have an active mrLoadRet session')
%     return
% end
% v = viewGet([],'view',vnums(1)); % assume only one view open. take first o.w.
% 
% % check that we are looking at a surface (otherwise the rest of the
% % function doesn't make sense!
% 
% if all(viewGet(v,'basetype') ~= [0 2])
%     % 0 is for multiview as well?
%     disp('(uhoh) - need to use this with a surface!')
%     return
% end
% 
% % get figure handle
% cFig = viewGet(v, 'fignum');
% 
% % get all handles to objects of type 'patch' in tree
% patchH = findobj(cFig,'-depth',inf,'type','patch');
% 
% make a new figure window and copy the patch objects over there...
newFig = figure;
newAxis = gca;
hSurface = patch('vertices', vertices, 'faces', faces,'FaceVertexCData', .6*ones(size(vertices,1),3),'facecolor','interp','edgecolor',edgeColor);
axis equal tight off vis3d

% as per refreshMLRDisplay, line 150 and onwards
% make sure x direction is normal to make right/right
set(newAxis,'XDir','reverse');
% NB! in mrSurfViewer the convention is the other way around?!
% make sure x direction is normal to make right/right
% set(newAxis,'XDir','normal');
set(newAxis,'YDir','normal');
set(newAxis,'ZDir','normal');


% fix camera projection, show toolbar and set some default material + light
% settings.
camproj('perspective')
cameratoolbar('setmode','nomode');
material dull % shiny metal
lighting phong

% initialize 3d view
view([az el]);
% update camlight for the first time
% needs to be BEHIND instead of headlight, to allow for the x-axis reversal
gL_ = camlight(180,0); 
% provide lighting from the _left_ also. because x-axis is back to front,
% the command is actually called with 'right'
gL2_ = camlight('right'); 

% enable 3d rotation here...
h = rotate3d(newFig);
% set the callback so that we can update the sliders
set(h,'ActionPostCallback',@myPostCallback);
set(h,'Enable','on');

% keyboard


% add some buttons and stuff...
uicontrol(newFig,'style','text','units','normalized','string',['Printing window for: '],'position',[.02 .02 .96 .03]);
% the text panels
azLabel = uicontrol(newFig,'style','text','horizontalalignment','left','units','normalized','string',['Az: ' num2str(az)],'position',[.3 .05 .1 .04]);
elLabel = uicontrol(newFig,'style','text','horizontalalignment','left','units','normalized','string',['El: ' num2str(el)],'position',[.3 .1 .1 .04]);
% and sliders
azSlider = uicontrol(newFig,'style','slide','units','normalized','position',[.02 .05 .25 .04], ...
    'min',-180,'max',+180,'val',az,'SliderStep',[10/360 20/360],'string', sprintf('az'),...
    'callback',@mySliderAzCallback,'createFcn',@mySliderAzCallback)  ;
elSlider = uicontrol(newFig,'style','slide','units','normalized','position',[.02 .1 .25 0.04], ...
    'min',-90,'max',90,'val',el,'SliderStep',[10/180 20/180],'string', sprintf('el'),...
    'callback',@mySliderElCallback,'createFcn',@mySliderElCallback)  ;

% a button for closing and a button for saving to PNG file.
uicontrol(newFig,'units','normalized','String', ['Save to file'] ,'position',[.02 .15 .25 .04], 'Callback', @printButtonCallback)
uicontrol(newFig,'units','normalized','String', ['Close'] ,'position',[.75 .05 .23 .04], 'Callback', @closeButtonCallback)




% ----- nested functions! definition below ----
% this reduces the need for global variables...

    function closeButtonCallback(h, evd)
        % callback function for close button
        disp('bye')
        close(newFig);
    end

% ---- slider callback functions ----------------------------------------
    function mySliderAzCallback(h, evd)
        % callback function for 3d rotate events
        % set new az
        az = round(get(h,'val'));
        adjustViewAngle(az, el) % set(newAxis,'view',[az, el]);
        set(azLabel,'string',sprintf('Az: %d',az));
    end

    function mySliderElCallback(h, evd)
        % callback function for 3d rotate events
        % set new az
        el = round(get(h,'val'));
        adjustViewAngle(az, el); % set(newAxis,'view',[az, el]);
        set(elLabel,'string',sprintf('El: %d',el));
    end

    function adjustViewAngle(hPos, vPos)
        % code snarfed from mrSurfViewer
        
        % flip the sign to make rotations go in the "right" direction
        hPos = -hPos;vPos = -vPos;
        % somehow 90 and 180 are a problem for matlab
        if abs(vPos) == 90,vPos = sign(vPos)*91;,end
        if abs(hPos) == 90,hPos = sign(hPos)*91;,end
        if abs(hPos) == 179,hPos = sign(hPos)*179;,end
        
        % set the size of the field of view in degrees
        % i.e. 90 would be very wide and 1 would be ver
        % narrow. 7 seems to fit the whole brain nicely
        
        % -- we choose not to do this here. in future might want to give
        % user control in a little gui dialog 
         
        camva(7);
        
        % set the view angle
        view(hPos,vPos);
        
        % change the camera position to avoid the volume
        % flipping back and forth, another starnge matlab thing
        if (vPos >= 90) || (vPos < -90)
            camup([0 0 -1]);
        else
            camup([0 0 1]);
        end
            % fix lighting again. camlight needs to be called at each change
            gL_ = camlight(gL_, 180, 0);
            gL2_ = camlight(gL2_,'right');
    end

    function myPostCallback(h, evd)
%        disp('(myPostCallBack) does nothing atmo') 
    end

% ---- print callback function ----------------------------------------

    function printButtonCallback(h,evd)
        disp('aha')
        % fName is available as we are in a nested function!
        if isempty(fName)
            [filename, pathname] = uiputfile({'*.png';'*.tiff';'*.jpg';'*.*'},'Save as');
            if isequal(filename,0) || isequal(pathname,0)
                disp('User pressed cancel')
                return
            else
                fName = fullfile(pathname, filename);
                disp(['User selected ', fName])
            end
        end
        
        % check that file is valid path? folders etc exist
        % get format from file extension.
        [pathName,fName,fExt] = fileparts(fName);
        if isempty(fExt), fExt = '.png'; end
        
        % -noui   to loose UI elements
        % -opengl to render with lights etc
        if any(strcmpi(fExt,{'.tif','.tiff'}))
            format = 'tiff';
        elseif any(strcmpi(fExt,{'.jpg','.jpeg'}))
            format = 'jpg';
        else
            format = 'png';
        end
        fprintf('Format for saving out is %s\n', format);
        
        print(newFig,'-noui','-opengl','-r300',sprintf('-d%s',format), fullfile(pathName,fName));
        fprintf('--wrote out %s\n', fName);
        
        
    end
end