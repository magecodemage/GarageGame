"""Detailed removable front suspension for the existing metric Golf reference.

Call build() in the already-open working scene. This module never resets,
loads, saves, exports or changes the supplied car. Coordinates in records
are Godot metres: +X driver-left, +Y up, +Z forward. Geometry is converted
to Blender (x, -z, y) and localized under unit-scale persistent-ID empties.
The reference represents service components, not a driving-physics rig.
"""

import math
import bpy
from mathutils import Matrix, Vector

_WHEEL_X = .742542
_WHEEL_Y = .307435
_WHEEL_Z = 1.195712
_TAG = "golf_front_suspension_v1"


def _b(point):
    return Vector((point[0], -point[2], point[1]))


def _v(point):
    return Vector(point)


def _material(name, color, metallic=.0, roughness=.55):
    material = bpy.data.materials.get(name)
    if material is None:
        material = bpy.data.materials.new(name)
        material.use_nodes = True
        shader = material.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = (*color, 1)
        shader.inputs['Metallic'].default_value = metallic
        shader.inputs['Roughness'].default_value = roughness
        material.diffuse_color = (*color, 1)
    return material


def _materials():
    return {
        'paint': _material('Suspension_Ecoat_Graphite', (.042, .052, .061), .5, .38),
        'cast': _material('Suspension_Cast_Iron', (.17, .19, .205), .65, .58),
        'alloy': _material('Suspension_Cast_Aluminium', (.37, .40, .415), .72, .42),
        'steel': _material('Suspension_Machined_Steel', (.47, .50, .53), .86, .26),
        'rotor': _material('Suspension_Rotor_Friction_Face', (.39, .41, .435), .92, .31),
        'chrome': _material('Suspension_Damper_Chrome', (.66, .7, .74), .97, .12),
        'rubber': _material('Suspension_Boot_Rubber', (.018, .022, .025), .0, .72),
        'pad': _material('Suspension_Pad_Composite', (.075, .077, .076), .08, .88),
        'zinc': _material('Suspension_Zinc_Hardware', (.47, .43, .29), .8, .35),
    }


def _root(identifier, origin):
    if bpy.data.objects.get(identifier) is not None:
        raise RuntimeError('Refusing to overwrite existing suspension object: ' + identifier)
    obj = bpy.data.objects.new(identifier, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = _b(origin)
    obj.empty_display_type = 'PLAIN_AXES'
    obj.empty_display_size = .055
    obj['persistent_id'] = identifier
    obj['origin_godot'] = list(origin)
    obj['generator'] = _TAG
    return obj


def _mesh(root, label, vertices, faces, material, smooth=False, bevel=0):
    origin = Vector(root['origin_godot'])
    mesh = bpy.data.meshes.new(root.name + '_' + label)
    mesh.from_pydata([_b(Vector(point) - origin) for point in vertices], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(mesh.name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = root
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.matrix_basis = Matrix.Identity(4)
    mesh.materials.append(material)
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    if bevel:
        modifier = obj.modifiers.new('Manufactured_edge_radii', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 3
        modifier.limit_method = 'ANGLE'
        # Apply before returning: exported geometry and gameplay bounds agree.
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)
    return obj


def _frame(axis):
    direction = Vector(axis).normalized()
    guide = Vector((0, 1, 0)) if abs(direction.y) < .9 else Vector((0, 0, 1))
    u = direction.cross(guide).normalized()
    v = direction.cross(u).normalized()
    return direction, u, v


def _lathe(root, label, base, axis, profile, material, segments=32):
    """Closed manufactured section revolved around an arbitrary metric axis.

    profile is a closed [(axial_distance, radius), ...] section: collars,
    conical castings, ventilated faces and rubber convolutions share this.
    """
    direction, u, v = _frame(axis)
    base = Vector(base)
    vertices = [base + direction*distance + (u*math.cos(angle*math.tau/segments) + v*math.sin(angle*math.tau/segments))*radius
                for distance, radius in profile for angle in range(segments)]
    faces = []
    for row in range(len(profile)):
        nxt = (row+1) % len(profile)
        for angle in range(segments):
            b = (angle+1) % segments
            faces.append((row*segments+angle,row*segments+b,nxt*segments+b,nxt*segments+angle))
    return _mesh(root, label, vertices, faces, material, True)


def _tube(root, label, points, radius, material, sides=12):
    points = [Vector(point) for point in points]
    vertices = []
    for index, point in enumerate(points):
        tangent = points[min(index+1,len(points)-1)]-points[max(index-1,0)]
        _,u,v = _frame(tangent)
        vertices.extend(point+(u*math.cos(k*math.tau/sides)+v*math.sin(k*math.tau/sides))*radius for k in range(sides))
    faces = [tuple(reversed(range(sides))),tuple((len(points)-1)*sides+k for k in range(sides))]
    for row in range(len(points)-1):
        for k in range(sides):
            faces.append((row*sides+k,row*sides+(k+1)%sides,(row+1)*sides+(k+1)%sides,(row+1)*sides+k))
    return _mesh(root,label,vertices,faces,material,True)


def _profile_prism(root,label,center,axis,u_axis,outline,depth,material,bevel=.002):
    direction = Vector(axis).normalized()
    u = Vector(u_axis).normalized()
    v = direction.cross(u).normalized()
    center = Vector(center)
    vertices = [center+u*a+v*b+direction*d for d in (-depth*.5,depth*.5) for a,b in outline]
    count=len(outline)
    faces=[tuple(reversed(range(count))),tuple(count+i for i in range(count))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    return _mesh(root,label,vertices,faces,material,False,bevel)


def _beam(root,label,a,b,width,height,material,bevel=.003):
    a,b=Vector(a),Vector(b)
    direction,u,v=_frame(b-a)
    # Octagonal pressed box-section, with chamfered corners rather than a box.
    profile=[(-width*.35,-height*.5),(width*.35,-height*.5),(width*.5,-height*.32),
             (width*.5,height*.32),(width*.35,height*.5),(-width*.35,height*.5),
             (-width*.5,height*.32),(-width*.5,-height*.32)]
    return _profile_prism(root,label,(a+b)*.5,direction,u,profile,(b-a).length,material,bevel)


def _bushing(root,label,position,axis,radius,length,m):
    _lathe(root,label+'_outer_shell',position,axis,[(-length/2,radius*.78),(-length/2,radius),(-length*.35,radius*1.06),
           (length*.35,radius*1.06),(length/2,radius),(length/2,radius*.78)],m['cast'])
    _lathe(root,label+'_rubber',position,axis,[(-length*.46,radius*.24),(-length*.46,radius*.78),
           (length*.46,radius*.78),(length*.46,radius*.24)],m['rubber'])
    _lathe(root,label+'_sleeve',position,axis,[(-length*.55,radius*.15),(-length*.55,radius*.25),
           (length*.55,radius*.25),(length*.55,radius*.15)],m['steel'],24)


def _bellows(root,label,a,b,radius,m,folds=7):
    a,b=Vector(a),Vector(b)
    length=(b-a).length
    profile=[(0,radius*.5),(0,radius*.76)]
    for index in range(folds):
        t=length*(index+.15)/folds
        profile.extend([(t,radius*.76),(t+length*.24/folds,radius),(t+length*.60/folds,radius*.76)])
    profile.extend([(length,radius*.65),(length,radius*.47)])
    _lathe(root,label,a,b-a,profile,m['rubber'],28)
    for fraction in (.015,.97):
        _lathe(root,label+'_band_'+str(fraction),a+(b-a)*fraction,b-a,[(-.002,radius*.64),(-.002,radius*.78),(.002,radius*.78),(.002,radius*.64)],m['steel'],28)


def _fastener(identifier,position,size,axis):
    return dict(id=identifier,position=[round(v,6) for v in position],size=size,axis=list(axis))


def _record(identifier,name,corner,origin,mass,fasteners=(),required=(),blocking=(),removed=(),loose=()):
    return dict(id=identifier,name=name,corner=corner,origin=[round(v,6) for v in origin],mass=mass,
                fasteners=list(fasteners),required_installed=list(required),blocking=list(blocking),
                required_removed=list(removed),loose_fasteners=list(loose),colliders=[])


def _front_subframe(m):
    identifier='front_subframe'
    origin=(0,.195,1.17)
    root=_root(identifier,origin)
    # Formed open H cradle: two curved rails, crossmembers and actual mounting eyes.
    for sign in (-1,1):
        rear=(sign*.35,.192,.91)
        waist=(sign*.28,.195,1.11)
        front=(sign*.35,.198,1.47)
        _beam(root,'rail_rear_'+str(sign),rear,waist,.070,.044,m['paint'],.005)
        _beam(root,'rail_front_'+str(sign),waist,front,.078,.044,m['paint'],.005)
        _beam(root,'rear_bush_cradle_'+str(sign),(sign*.25,.202,.97),(sign*.35,.202,.97),.070,.045,m['paint'])
        _beam(root,'front_bush_cradle_'+str(sign),(sign*.23,.203,1.34),(sign*.33,.203,1.34),.064,.045,m['paint'])
        for z in (.91,1.47):
            _bushing(root,'body_mount_'+str(sign)+'_'+str(z),(sign*.35,.22,z),(0,1,0),.040,.050,m)
    _beam(root,'rear_crossmember',(-.35,.195,.91),(.35,.195,.91),.072,.046,m['paint'],.005)
    _beam(root,'front_crossmember',(-.35,.193,1.47),(.35,.193,1.47),.066,.043,m['paint'],.005)
    # Anti-roll bar belongs to the cradle in this development assembly.
    sway=[(-.60,.270,1.34),(-.57,.256,1.15),(-.46,.25,.95),(-.3,.245,.90),(.3,.245,.90),(.46,.25,.95),(.57,.256,1.15),(.60,.270,1.34)]
    _tube(root,'bent_anti_roll_bar',sway,.012,m['paint'],16)
    for sign in (-1,1):
        _bushing(root,'anti_roll_saddle_'+str(sign),(sign*.30,.245,.90),(1,0,0),.020,.033,m)
    _lathe(root,'steering_rack_housing',(0,.300,.975),(1,0,0),
           [(-.22,.008),(-.22,.025),(-.11,.029),(.12,.027),(.22,.021),(.22,.008)],m['alloy'],32)
    for sign in (-1,1):
        _bellows(root,'steering_rack_boot_'+str(sign),(sign*.20,.300,.975),(sign*.345,.300,.975),.026,m,8)
    bolts=[_fastener('front_subframe_mount_'+str(index+1),(sign*.35,.253,z),21,(0,1,0))
           for index,(sign,z) in enumerate(((-1,.91),(1,.91),(-1,1.47),(1,1.47)))]
    blockers=[f'front_{side}_{part}' for side in ('left','right') for part in ('lower_control_arm','tie_rod_end','cv_axle','stabilizer_link')]
    return _record(identifier,'Agregado dianteiro','front',origin,18.5,bolts,blocking=blockers)


def _corner(side,sign,m):
    prefix='front_'+side+'_'
    corner='fl' if sign>0 else 'fr'
    records=[]
    wheel=prefix+'wheel'
    def p(x,y,z):
        return Vector((sign*x,y,z))
    def make(part,name,origin,mass,fasteners=(),required=(),blocking=(),removed=(),loose=()):
        identifier=prefix+part
        obj=_root(identifier,origin)
        records.append(_record(identifier,name,corner,origin,mass,fasteners,required,blocking,removed,loose))
        return obj
    suffix='dianteiro esquerdo' if sign>0 else 'dianteiro direito'
    axle=p(_WHEEL_X,_WHEEL_Y,_WHEEL_Z)
    lower=p(.603,.348,1.176)
    upper=p(.530,.852,1.142)
    direction=(upper-lower).normalized()
    length=(upper-lower).length

    root=make('strut','Amortecedor '+suffix,(lower+upper)*.5,5.1,
        [_fastener(prefix+'strut_upper_bolt',p(.476,.882,1.142),13,(0,1,0)),
         _fastener(prefix+'strut_upper_mount_bolt_2',p(.584,.882,1.142),13,(0,1,0))],
        required=[prefix+'spring'],blocking=[prefix+'stabilizer_link'],
        loose=[prefix+'strut_lower_bolt',prefix+'strut_lower_clamp_bolt_2'])
    records[-1]['required_secure']=[prefix+'spring']
    _lathe(root,'damper_body',lower,direction,[(0,.006),(0,.019),(.014,.024),(.269,.024),(.283,.021),(.29,.012),(.29,.006)],m['paint'])
    _lathe(root,'chrome_piston',lower,direction,[(.265,.007),(.265,.011),(.479,.011),(.489,.008),(.489,.007)],m['chrome'])
    _lathe(root,'lower_spring_perch',lower,direction,[(.282,.022),(.282,.065),(.292,.080),(.302,.081),(.305,.070),(.293,.022)],m['paint'],48)
    _lathe(root,'perch_rubber_isolator',lower,direction,[(.302,.051),(.302,.073),(.310,.073),(.310,.051)],m['rubber'],40)
    _bellows(root,'piston_dust_gaiter',lower+direction*.295,lower+direction*.447,.025,m,9)
    _lathe(root,'upper_spring_seat',lower,direction,[(.454,.015),(.454,.073),(.461,.077),(.47,.064),(.477,.036),(.477,.015)],m['paint'],48)
    _lathe(root,'top_mount_rubber',upper,direction,[(-.018,.014),(-.018,.049),(-.006,.061),(.007,.055),(.014,.039),(.014,.014)],m['rubber'],40)
    _lathe(root,'top_mount_bearing',upper,direction,[(.008,.012),(.008,.035),(.017,.034),(.021,.020),(.021,.012)],m['steel'])
    # Separate tower fixings from the central spring retainer. The old two
    # bolt heads were inside the bearing crown instead of on a mounting plate.
    _lathe(root,'tower_mounting_plate',upper+Vector((0,.011,0)),(0,1,0),
           [(0,.038),(0,.072),(.010,.072),(.010,.038)],m['steel'],48)
    _beam(root,'stabilizer_bracket',p(.588,.540,1.165),p(.598,.548,1.231),.025,.020,m['paint'])

    spring_origin=lower+direction*.381
    root=make('spring','Mola helicoidal '+suffix,spring_origin,2.5,
        [_fastener(prefix+'spring_retainer_nut',p(.530,.882,1.142),21,(0,1,0))])
    records[-1]['assembly_parent']=prefix+'strut'
    records[-1]['service_requires_removed']=[prefix+'strut']
    _,u,v=_frame(direction)
    turns=5.0
    coil=[]
    for index in range(241):
        t=index/240
        # Closely wound end turns, with open working coils between the seats.
        axial=.316+.130*(.10*t+.90*(.5-.5*math.cos(math.pi*t)))
        radius=.063-.006*(abs(t-.5)*2)**4
        angle=t*turns*math.tau
        coil.append(lower+direction*axial+(u*math.cos(angle)+v*math.sin(angle))*radius)
    _tube(root,'wound_spring_steel',coil,.0074,m['paint'],10)

    inner_rear=p(.32,.208,.97)
    inner_front=p(.28,.208,1.34)
    ball=p(.651,.207,1.196)
    arm_origin=(inner_rear+inner_front+ball)/3
    root=make('lower_control_arm','Bandeja inferior '+suffix,arm_origin,3.6,
        [_fastener(prefix+'control_arm_rear_bolt',p(.32,.255,.97),18,(0,1,0)),
         _fastener(prefix+'control_arm_front_bolt',p(.28,.252,1.34),18,(0,1,0))],
        required=['front_subframe'],blocking=[prefix+'ball_joint',prefix+'stabilizer_link'])
    # Three formed webs enclose a visible triangular lightening opening.
    _beam(root,'pressed_front_web',inner_front,ball,.048,.029,m['paint'],.005)
    _beam(root,'pressed_rear_web',inner_rear,ball,.052,.030,m['paint'],.005)
    _beam(root,'pressed_inner_web',inner_rear,inner_front,.042,.028,m['paint'],.004)
    for name,point,radius in [('rear',inner_rear,.046),('front',inner_front,.035)]:
        _bushing(root,name+'_pivot',point,(0,1,0),radius,.055,m)
    _lathe(root,'ball_joint_platform',ball,(0,1,0),[(-.014,.025),(-.014,.050),(.014,.050),(.014,.025)],m['paint'],36)
    _beam(root,'front_pressing_rib',inner_front+Vector((0,.015,0)),ball+Vector((0,.015,0)),.013,.008,m['cast'],.001)
    _beam(root,'rear_pressing_rib',inner_rear+Vector((0,.015,0)),ball+Vector((0,.015,0)),.013,.008,m['cast'],.001)

    root=make('ball_joint','Pivô da suspensão '+suffix,ball, .58,
        [_fastener(prefix+'ball_joint_fastener',ball+Vector((sign*.026,.025,.017)),16,(0,1,0))],
        required=[prefix+'lower_control_arm'])
    _profile_prism(root,'three_bolt_flange',ball,(0,1,0),(1,0,0),[(-.043,-.029),(.04,-.023),(.022,.041),(-.019,.046)],.017,m['alloy'],.004)
    _lathe(root,'forged_joint_body',ball,(0,1,0),[(-.030,.012),(-.029,.023),(-.011,.031),(.014,.026),(.026,.017),(.026,.012)],m['cast'])
    _bellows(root,'sealed_joint_boot',ball+Vector((0,.019,0)),ball+Vector((0,.052,0)),.024,m,3)
    _lathe(root,'tapered_pin',ball,(0,1,0),[(.028,.004),(.028,.011),(.064,.009),(.069,.007),(.069,.004)],m['steel'],24)

    knuckle_origin=p(.653,_WHEEL_Y,_WHEEL_Z)
    root=make('knuckle','Manga de eixo '+suffix,knuckle_origin,4.1,
        [_fastener(prefix+'strut_lower_bolt',p(.646,.432,1.178),18,(sign,0,0)),
         _fastener(prefix+'strut_lower_clamp_bolt_2',p(.646,.398,1.178),18,(sign,0,0))],
        required=[prefix+'strut',prefix+'ball_joint'],
        blocking=[prefix+'hub',prefix+'brake_caliper',prefix+'tie_rod_end',prefix+'cv_axle',prefix+'ball_joint'])
    _lathe(root,'bearing_casting',knuckle_origin,(sign,0,0),[(-.036,.034),(-.036,.046),(-.021,.059),(.014,.061),(.033,.047),(.033,.034)],m['cast'],40)
    _beam(root,'cast_upright',p(.646,.334,1.193),p(.609,.446,1.178),.064,.059,m['cast'],.007)
    _lathe(root,'split_strut_clamp',p(.609,.422,1.178),direction,[(-.029,.0245),(-.029,.037),(.030,.037),(.030,.0245)],m['cast'],32)
    _beam(root,'lower_joint_fork',p(.653,.28,1.196),p(.651,.252,1.196),.044,.040,m['cast'],.005)
    _beam(root,'steering_arm',p(.646,.314,1.162),p(.60,.310,1.053),.036,.030,m['cast'],.005)
    for y in (.231,.388):
        _beam(root,'caliper_mount_ear_'+str(y),p(.653,_WHEEL_Y,1.223),p(.680,y,1.350),.033,.029,m['cast'],.005)

    hub_origin=p(.725,_WHEEL_Y,_WHEEL_Z)
    root=make('hub','Cubo de roda '+suffix,hub_origin,2.2,
        [_fastener(prefix+'hub_bolt_1',p(.689,.265,1.157),17,(sign,0,0)),
         _fastener(prefix+'hub_bolt_2',p(.689,.350,1.234),17,(sign,0,0))],
        required=[prefix+'knuckle'],blocking=[wheel,prefix+'brake_disc',prefix+'cv_axle'])
    _lathe(root,'bearing_and_drive_sleeve',axle,(sign,0,0),[(-.090,.018),(-.090,.030),(-.070,.037),(-.023,.036),(-.008,.026),(.029,.028),(.029,.018)],m['steel'],40)
    _lathe(root,'machined_flange_core',axle,(sign,0,0),[(.008,.025),(.008,.045),(.021,.045),(.024,.032),(.024,.025)],m['steel'],40)
    for i in range(5):
        angle=i*math.tau/5+math.pi*.5
        eye=axle+Vector((sign*.015,.051*math.sin(angle),.051*math.cos(angle)))
        _lathe(root,'threaded_wheel_hole_'+str(i+1),eye,(sign,0,0),[(-.006,.0065),(-.006,.012),(.007,.012),(.007,.0065)],m['steel'],20)
        spoke_start=axle+Vector((sign*.015,.032*math.sin(angle),.032*math.cos(angle)))
        _beam(root,'five_lug_flange_arm_'+str(i+1),spoke_start,eye,.017,.012,m['steel'],.002)

    disc_origin=axle
    root=make('brake_disc','Disco ventilado '+suffix,disc_origin,6.6,
        [_fastener(prefix+'brake_disc_screw_1',axle+Vector((sign*.028,.046,.025)),13,(sign,0,0)),
         _fastener(prefix+'brake_disc_screw_2',axle+Vector((sign*.028,-.046,-.025)),13,(sign,0,0))],
        required=[prefix+'hub'],blocking=[wheel,prefix+'brake_caliper'])
    _lathe(root,'cast_hat',axle,(sign,0,0),[(-.013,.033),(-.013,.073),(-.009,.077),(.012,.060),(.025,.060),(.025,.033)],m['cast'],64)
    for name,x0,x1 in [('inboard',-.025,-.020),('outboard',.002,.007)]:
        _lathe(root,name+'_friction_ring',axle,(sign,0,0),[(x0,.071),(x0,.165),(x0+.001,.167),(x1-.001,.167),(x1,.165),(x1,.071)],m['rotor'],96)
    for i in range(32):
        angle=i*math.tau/32
        a=axle+Vector((-sign*.009,.078*math.cos(angle),.078*math.sin(angle)))
        b=axle+Vector((-sign*.009,.159*math.cos(angle+.10),.159*math.sin(angle+.10)))
        _beam(root,'internal_cooling_vane_'+str(i),a,b,.020,.006,m['cast'],.0007)
    # Narrow concentric machining lands retain a readable friction surface.
    for radius in (.081,.119,.160):
        _lathe(root,'machining_land_'+str(radius),axle,(sign,0,0),[(.007,radius-.0005),(.007,radius+.0005),(.0073,radius+.0005),(.0073,radius-.0005)],m['steel'],96)

    caliper_origin=p(.735,_WHEEL_Y,1.333)
    root=make('brake_caliper','Pinça de freio '+suffix,caliper_origin,3.2,
        [_fastener(prefix+'brake_caliper_bolt_1',p(.654,.226,1.350),16,(-sign,0,0)),
         _fastener(prefix+'brake_caliper_bolt_2',p(.654,.388,1.350),16,(-sign,0,0))],
        required=[prefix+'knuckle',prefix+'brake_disc'],blocking=[wheel])
    outline=[(-.094,-.018),(-.096,.018),(-.075,.043),(-.028,.050),(.034,.049),(.082,.034),(.096,.006),(.090,-.026),(.050,-.039),(-.058,-.039)]
    # Two cast jaws and end bridges leave a real rotor/pad inspection window.
    # Wheel-triangle audit: the old outer jaw and slider bosses cut the real
    # rim barrel/spokes. Retain both rotor faces and pads, reprofile only the
    # casting outside them, and move both matching slider mounting ears.
    for label,x,depth in [('piston_jaw',.694,.044),('outer_jaw',.772,.024)]:
        _profile_prism(root,label,p(x,_WHEEL_Y,1.331),(1,0,0),(0,1,0),outline,depth,m['cast'],.005)
    for y in (.226,.388):
        _beam(root,'caliper_bridge_'+str(y),p(.690,y,1.335),p(.782,y,1.335),.038,.030,m['cast'],.005)
        _lathe(root,'slider_mount_boss_'+str(y),p(.676,y,1.350),(sign,0,0),
               [(-.013,.006),(-.013,.018),(.010,.018),(.010,.006)],m['cast'],24)
    for x in (.713,.754):
        _profile_prism(root,'friction_pad_'+str(x),p(x,_WHEEL_Y,1.310),(1,0,0),(0,1,0),[(-.065,-.021),(-.067,.018),(-.032,.031),(.037,.030),(.067,.010),(.062,-.024)],.009,m['pad'],.002)
    _lathe(root,'piston_cast_dome',p(.676,_WHEEL_Y,1.328),(sign,0,0),[(-.005,.012),(-.005,.028),(.005,.035),(.016,.032),(.020,.025),(.020,.012)],m['cast'],32)
    _tube(root,'outer_retaining_spring',[p(.786,.236,1.323),p(.788,.263,1.349),p(.788,.350,1.349),p(.786,.379,1.323)],.003,m['steel'],8)
    _lathe(root,'bleed_nipple',p(.700,.405,1.329),(0,1,0),[(0,.004),(0,.008),(.008,.007),(.018,.004),(.018,.003)],m['zinc'],12)

    tie_outer=p(.601,.308,1.055)
    tie_inner=p(.345,.300,.975)
    root=make('tie_rod_end','Terminal de direção '+suffix,(tie_outer+tie_inner)*.5,.82,
        [_fastener(prefix+'tie_rod_end_nut',tie_outer+Vector((0,.033,0)),19,(0,1,0))],
        required=['front_subframe',prefix+'knuckle'])
    _tube(root,'tapered_steering_shank',[tie_inner,tie_inner+(tie_outer-tie_inner)*.18,tie_outer],.012,m['steel'],16)
    _lathe(root,'adjusting_locknut',tie_inner+(tie_outer-tie_inner)*.24,tie_outer-tie_inner,[(-.009,.011),(-.009,.018),(.009,.018),(.009,.011)],m['zinc'],6)
    _lathe(root,'forged_socket',tie_outer,(0,1,0),[(-.021,.008),(-.021,.017),(-.011,.024),(.007,.024),(.016,.016),(.016,.008)],m['cast'],28)
    _bellows(root,'terminal_boot',tie_outer+Vector((0,.009,0)),tie_outer+Vector((0,.025,0)),.018,m,3)
    _lathe(root,'terminal_taper_pin',tie_outer,(0,1,0),[(.01,.003),(.01,.008),(.035,.007),(.035,.003)],m['steel'],20)

    link_bottom=p(.600,.270,1.340)
    link_top=p(.598,.548,1.231)
    root=make('stabilizer_link','Bieleta '+suffix,(link_bottom+link_top)*.5,.43,
        [_fastener(prefix+'stabilizer_link_lower_nut',link_bottom+Vector((sign*.025,0,0)),16,(sign,0,0)),
         _fastener(prefix+'stabilizer_link_upper_nut',link_top+Vector((sign*.025,0,0)),16,(sign,0,0))],
        required=['front_subframe',prefix+'strut',prefix+'lower_control_arm'])
    _tube(root,'link_shank',[link_bottom,link_bottom+(link_top-link_bottom)*.12,link_top],.008,m['paint'],14)
    for label,point in [('lower',link_bottom),('upper',link_top)]:
        _lathe(root,label+'_ball_socket',point,(sign,0,0),[(-.012,.004),(-.012,.013),(-.005,.018),(.008,.018),(.015,.012),(.015,.004)],m['cast'],24)
        _bellows(root,label+'_boot',point+Vector((sign*.011,0,0)),point+Vector((sign*.026,0,0)),.013,m,3)

    cv_inner=p(.180,.280,1.000)
    cv_outer=p(.667,_WHEEL_Y,_WHEEL_Z)
    cv_direction=(cv_outer-cv_inner).normalized()
    cv_length=(cv_outer-cv_inner).length
    root=make('cv_axle','Semieixo homocinético '+suffix,(cv_inner+cv_outer)*.5,5.2,
        [_fastener(prefix+'cv_axle_hub_nut',axle+Vector((sign*.067,0,0)),21,(sign,0,0))]+
        [_fastener(prefix+'cv_axle_inner_bolt_'+str(i+1),cv_inner+Vector((sign*.035,.049*math.cos(i*math.tau/3),.049*math.sin(i*math.tau/3))),17,(sign,0,0)) for i in range(3)],
        required=['front_subframe',prefix+'knuckle',prefix+'hub'],blocking=[wheel])
    _lathe(root,'drive_shaft',cv_inner,cv_direction,[(0,.009),(0,.014),(.07,.016),(cv_length-.075,.014),(cv_length,.022),(cv_length,.009)],m['steel'],24)
    _lathe(root,'inner_joint_cup',cv_inner,cv_direction,[(-.020,.012),(-.02,.031),(0,.039),(.035,.038),(.045,.028),(.045,.012)],m['cast'],32)
    _lathe(root,'inner_joint_mount_flange',cv_inner,(sign,0,0),
           [(.012,.016),(.012,.062),(.026,.062),(.026,.016)],m['steel'],48)
    _bellows(root,'inner_cv_boot',cv_inner+cv_direction*.031,cv_inner+cv_direction*.133,.037,m,6)
    _bellows(root,'outer_cv_boot',cv_outer-cv_direction*.130,cv_outer-cv_direction*.024,.044,m,7)
    _lathe(root,'outer_cv_bell',cv_outer,cv_direction,[(-.039,.013),(-.039,.035),(-.026,.044),(.022,.042),(.033,.029),(.041,.020),(.041,.013)],m['steel'],36)
    _lathe(root,'hub_drive_stub',cv_outer,(sign,0,0),[(0,.01),(0,.019),(.130,.019),(.139,.015),(.139,.010)],m['steel'],24)
    return records


def build():
    """Create 23 parts, return their metadata, leave the loaded scene intact.

    Safe repeat behavior is fail-before-write if any persistent root exists.
    The caller can build in a fresh working copy; no broad deletion is used.
    Spring metadata deliberately leaves nested carrying/service rules to the
    gameplay integrator. No fictional spring bolt is introduced here.
    """
    identifiers=['front_subframe']+[f'front_{side}_{part}' for side in ('left','right') for part in
        ('strut','spring','knuckle','hub','brake_disc','brake_caliper','lower_control_arm','ball_joint','tie_rod_end','stabilizer_link','cv_axle')]
    collisions=[identifier for identifier in identifiers if bpy.data.objects.get(identifier)]
    if collisions:
        raise RuntimeError('Existing persistent roots must be handled by caller: '+', '.join(collisions))
    m=_materials()
    records=[_front_subframe(m)]
    records.extend(_corner('left',1,m))
    records.extend(_corner('right',-1,m))
    bpy.context.view_layer.update()
    return records
