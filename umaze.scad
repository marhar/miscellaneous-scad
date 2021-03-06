horizontalCells = 8;
verticalCells = 8;
cellSize = 12.5;
innerWallThickness = 0.75;
innerWallHeight = 11.5;
outerWallThickness = 2;
outerWallHeight = 11.5;
baseThickness = 1;
flareSize = 0; // 2.4;
startAndEndMarkers = 0; // [0:No, 1:Yes]
startInset = 0.5;
// set seed to something other than 0 for a repeatable design
seed = 5;

module dummy() {}

$fn = 16;

nudge = 0.001;

// Algorithm:   https://en.wikipedia.org/wiki/Maze_generation_algorithm#Recursive_backtracker

// cell structure: [visited, [wall1, wall2, ...]]
// position: [x,y]
// direction: 0,1,2,3

directions = [ [-1,0], [1,0], [0,-1], [0,1] ];
wallCoordinates = [ [ [-0.5,-0.5],[-0.5,0.5] ],
    [ [0.5,-0.5],[0.5,0.5] ],
    [ [-0.5,-0.5],[0.5,-0.5] ],
    [ [-0.5,0.5],[0.5,0.5] ] ];
revDirections = [1,0,3,2];
nDirs = len(directions);

function r(n) = floor(rands(0,n-1e-6,1)[0]);

function inside(pos) = pos[0] >= 0 && pos[1] >= 0 && pos[0] < horizontalCells && pos[1] < verticalCells;

function rdir(pos) = 
    let(dir=r(nDirs))
        inside(move(pos,dir)) ? dir : rdir(pos);

function move(pos,dir) = pos+directions[dir];
function tail(list) = len(list)>1 ? [for(i=[1:len(list)-1]) list[i]] : [];
function visited(cells,pos) = !inside(pos) || cells[pos[0]][pos[1]][0] > 0;
function visit(cells, pos, dir) = 
    let(newPos=move(pos,dir))
    [ [ for(x=[0:horizontalCells-1]) [ for(y=[0:verticalCells-1]) 
        [ [x,y]==pos ? -(1+dir) : cells[x][y][0], cells[x][y][1] ] ] ], newPos ];
        
function unvisited(cells) =
    [for(x=[0:horizontalCells-1]) 
         for(y=[0:verticalCells-1])
             if (cells[x][y][0]==0) 
                 [x,y]];

function randomUnvisited0(cells,pos) =
    cells[pos[0]][pos[1]][0] == 0 ? pos
        : randomUnvisited0(cells,[r(horizontalCells),r(verticalCells)]);
    
function choose(v) = v[r(len(v))];
             
function randomUnvisited(cells) = randomUnvisited0(cells,[r(horizontalCells),r(verticalCells)]);
             
// this is ugly, but it's like that
// to ensure tail recursion, which doesn't allow let()             
function randomPath(cells_pos) = 
    cells_pos[0][cells_pos[1][0]][cells_pos[1][1]][0] > 0 ? cells_pos[0] :
        randomPath(visit(cells_pos[0],cells_pos[1],rdir(cells_pos[1])));
    
function addPath(cells) = 
    let(pos=choose(unvisited(cells)),
        build=randomPath([cells,pos]))
    [ for(x=[0:horizontalCells-1]) [ for(y=[0:verticalCells-1]) 
        build[x][y][0] < 0 ? [ 1, 
            [ for(dir=[0:nDirs-1]) 
                build[x][y][1][dir] && -1-dir != build[x][y][0] ] ] :
           build[x][y] ] ];

function cleanWalls(cells) =
    [ for(x=[0:horizontalCells-1]) [ for(y=[0:verticalCells-1]) 
        [ cells[x][y][0],
            [for(dir=[0:nDirs-1])
                let(revDir=revDirections[dir],
                    prev=move([x,y],revDir))
                cells[x][y][1][dir] && (! inside(prev) || cells[prev[0]][prev[1]][1][revDir] ) ] ] ] ];
                     
function iterateMaze(cells) = 
    len(unvisited(cells)) == 0 ? 
        cells :
        iterateMaze(addPath(cells));
        
function baseMaze(pos) = 
    [ for(x=[0:horizontalCells-1]) [ for(y=[0:verticalCells-1]) 
        [ [x,y] == pos ? 1 : 0,
        [for (i=[0:nDirs-1])
            inside(move([x,y],i))] ] ] ];

function revisit(maze,pos) = 
    [ for(x=[0:horizontalCells-1]) [ for(y=[0:verticalCells-1]) 
        [ [x,y] == pos,
          maze[x][y][1] ] ] ];

function getLongest(options,pos=0,best=[]) =
        len(options)<=pos ? best :
    getLongest(options,pos=pos+1,best=    best[0]>=options[pos][0] ? best : options[pos]);

function walled(cells,pos,dir) =
    cells[pos[0]][pos[1]][1][dir];

function countUnvisitedNeighborsWalled(cells,pos,count=0, dir=0) = dir >= len(directions) ? 
        count :        
        countUnvisitedNeighborsWalled(cells, pos, count = count + ((walled(cells,pos,dir) || visited(cells,move(pos,dir)))?0:1), dir = dir+1);
function getNthUnvisitedNeighborWalled(cells,pos,count,dir=0) =
    (walled(cells,pos,dir) || visited(cells,move(pos,dir))) ?
        getNthUnvisitedNeighborWalled(cells,pos,count,dir=dir+1) :
    count == 0 ? dir :
        getNthUnvisitedNeighborWalled(cells,pos,count-1,dir=dir+1);

function furthest(maze,pos,length=1)
    = let(n=countUnvisitedNeighborsWalled(maze,pos))
      n == 0 ? [length,pos] :
      getLongest([for (i=[0:n-1]) 
         let(dir=getNthUnvisitedNeighborWalled(maze,pos,i))
         furthest(visit(maze,pos,dir),move(pos,dir),length=length+1)]);


module renderWall(dir,spacing) {
    hull() {
        translate(spacing*wallCoordinates[dir][0])
            children();
        translate(spacing*wallCoordinates[dir][1])
            children();
    }
}

module renderInside(maze,spacing=10) {
    translate(spacing*[0.5,0.5])
    for (x=[0:len(maze)-1])
        for(y=[0:len(maze[0])-1]) {
            translate([x,y,0]*spacing)
                for(i=[0:len(directions)-1])
                    if (maze[x][y][1][i]) renderWall(i,spacing) children();
        }
}

module renderOutside(offset, spacing=10) {
    for(wall=wallCoordinates) {
        hull() {
            for(i=[0:1])
            translate([(0.5+wall[i][0])*spacing*horizontalCells+offset*sign(wall[i][0]),(0.5+wall[i][1])*spacing*verticalCells+offset*sign(wall[i][1])]) children();
        }
    }
}

module innerWall() {
    linear_extrude(height=innerWallHeight) circle(d=innerWallThickness, center=true);
}

module innerWallFlare() {
    translate([0,0,innerWallHeight-flareSize]) linear_extrude(height=flareSize,scale=(flareSize*2+innerWallThickness)/innerWallThickness) circle(d=innerWallThickness,center=true);
}

module mazeBox(h) {
    linear_extrude(height=h) hull() renderOutside(max(0,(outerWallThickness-innerWallThickness)/2),spacing=cellSize) circle(d=outerWallThickness);
}

module hole(x,y,position,spacing=10) {
    if (position != 0) {
        holeSize=spacing-innerWallThickness;
        translate([(x+0.5)*spacing,(y+0.5)*spacing,0])
        if (position>0) {
            translate([0,0,baseThickness+nudge-startInset]) cylinder(h=outerWallHeight+innerWallHeight,d=holeSize,$fn=32);
        }
        else {
            translate([0,0,-nudge]) cylinder(h=baseThickness+3*nudge,d=holeSize,$fn=32);
        }
    }
}
        
module maze0() {
    start = [r(horizontalCells),r(verticalCells)];
    maze = cleanWalls(iterateMaze(baseMaze(start), start));
    echo(maze);
    difference() {
        union() {

            translate([0,0,baseThickness]) {
                renderInside(maze, spacing=cellSize)            innerWall();
                if (flareSize>0)
                    renderInside(maze, spacing=cellSize)            innerWallFlare();
            renderOutside(max(0,(outerWallThickness-innerWallThickness)/2),spacing=cellSize) cylinder(d=outerWallThickness,h=outerWallHeight);        
            if(flareSize>0)
            renderOutside(0, spacing=cellSize)            innerWallFlare();
            }

            if(baseThickness>0)
                mazeBox(baseThickness+nudge);
        }
        if(startAndEndMarkers) {
            options = 
                [for (pos=[[0,0],[horizontalCells-1,0],[horizontalCells-1,verticalCells-1],[0,verticalCells-1]])
                    concat(furthest(revisit(maze,pos),pos), [pos]) ];
            f = getLongest(options);
            start = f[2];
            end = f[1];
            
            hole(end[0],end[1],-1,spacing=cellSize);
            hole(start[0],start[1],1,spacing=cellSize);
        }
    }
}

module maze() {
    if (flareSize>0) 
    intersection() {
      maze0();
      mazeBox(h=baseThickness+outerWallHeight+innerWallHeight);
    }
    else maze0();
}

maze();