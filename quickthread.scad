function _ringPoints(param) = len(param[0]);
function _ringValue(param,point) = param[0][point];
function _numTurns(param) = param[2];
function _numRings(param) = 1+_numTurns(param)*$fn;
function _radius(param) = param[1];
function _lead(param) = param[3];

extrNudge = 0.001;

function extrPoints(param) = 
    let (n=_ringPoints(param),
        r=_radius(param),
        m=_numRings(param),
        l=_lead(param)
        ) 
        [ for (i=[0:m-1]) for (j=[0:n-1]) 
            let (z=i/$fn*l,
                angle=(i%$fn)/$fn*360,
                v=_ringValue(param,j))
            [ (r+v[0])*cos(angle), (r+v[0])*sin(angle),z+v[1]] ];
        
function mod(m,n) = let(mm = m%n) mm<0 ? n+mm : mm;
        
function extrPointIndex(param,ring,point) = 
    let (n=_ringPoints(param)) 
        n*ring + mod(point,n);
        
function startFacePoints(param) = 
    let (n=_ringPoints(param)) 
        [for (i=[0:n-1]) extrPointIndex(param,0,i)];
            
function endFacePoints(param) = 
    let (m=_numRings(param), n=_ringPoints(param)) 
            [for (i=[n-1:-1:0]) extrPointIndex(param,m-1,i)];
                
function tubeFaces(param) =
    let (m=_numRings(param), n=_ringPoints(param))
            [for (i=[0:m-2]) for (j=[0:n-1]) for(tri=[0:1])
                tri==0 ? 
                    [extrPointIndex(param,i,j),extrPointIndex(param,i+1,j),extrPointIndex(param,i,j+1)] :
                    [extrPointIndex(param,i,j+1), extrPointIndex(param,i+1,j),
            extrPointIndex(param,i+1,j+1)]];
                

function extrFaces(param) = concat([startFacePoints(param)],concat(tubeFaces(param),[endFacePoints(param)]));

                    
module rawThread(profile, d=undef, h=10, lead=undef, $fn=72, adjustRadius=false, clip=true, includeCylinder=true) {
    radius = d/2;
    vSize = max([for(v1=profile) for(v2=profile) v2[1]-v1[1]]);
    vMin = min([for(v=profile) v[0]]);
    radiusAdjustment = adjustRadius ? vMin : 0;
    _lead = lead==undef ? vSize : lead;
    profileScale = vSize <= _lead-extrNudge ? 1 : (_lead-extrNudge)/vSize;
    adjProfile = [for(v=profile) [v[0]-radiusAdjustment,v[1]*profileScale]];
    adjRadius = radius + radiusAdjustment;
    hSize = 1+2*adjRadius + 2*max([for (v=adjProfile) v[0]]);
    numTurns = 2+ceil(h/_lead);
    param = [adjProfile, adjRadius, numTurns, _lead];
    render(convexity=10)
    union() {
        intersection() {
            if (clip)
                translate([-hSize/2,-hSize/2,0]) cube([hSize,hSize,h]);
            translate([0,0,-_lead]) polyhedron(faces=extrFaces(param),points=extrPoints(param));
        }
        if (includeCylinder) 
            cylinder(r=adjRadius+extrNudge,$fn=$fn,h=h);
    }
}

function inch_to_mm(x) = x * 25.4;

// internal = female
module isoThread(d=undef, dInch=undef, pitch=1, tpi=undef, h=1, hInch=undef, lead=undef, leadInch=undef, angle=30, internal=false, $fn=72) {

    P = (tpi==undef) ? pitch : tpi;

    radius = dInch != undef ? inch_to_mm(dInch)/2 : d/2;    
    height = hInch != undef ? inch_to_mm(hInch) : h;
     
    Dmaj = 2*radius;
    H = P * cos(angle);
    
    _lead = leadInch != undef ? inch_to_mm(leadInch) : lead != undef ? lead : P;
    
    externalExtra=0.03;
    internalExtra=0.057;
    profile = !internal ? 
        [ [-H*externalExtra,(-3/8-externalExtra)*P], 
          [(5/8)*H,-P/16],[(5/8)*H,P/16], 
          [-H*externalExtra,(3/8+externalExtra)*pitch] ] :
        [ [0,-(3/8)*P], 
        [(5/8)*H,-P/16],[(5/8+internalExtra)*H,0],
        [(5/8)*H,P/16],[0,(3/8)*P] ];
    Dmin = Dmaj-2*H/4;
    myFN=$fn;
    rawThread(profile,d=Dmin,h=height,lead=_lead,$fn=myFN,adjustRadius=true);        
}

//rawThread([[0,0],[1.5,1.5],[0,3]], d=50, h=91, pitch=3);
//rawThread([[0,0],[0,3],[3,3],[3,0]], d=50, h=50, pitch=6, $fn=80);
difference() {
    isoThread(d=50,h=30,pitch=3,angle=40,internal=false,$fn=60);
    translate([0,0,-extrNudge]) isoThread(d=42,h=30+2*extrNudge,pitch=3,angle=40,internal=true,$fn=60);
}
//rawThread([[0,0],[1,0],[.5,.5],[1,1],[0,1]],r=20,h=10,lead=1.5);
