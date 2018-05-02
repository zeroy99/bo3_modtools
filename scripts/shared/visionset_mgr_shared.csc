	
#namespace visionset_mgr;

function register_visionset_info( name, version, lerp_step_count, visionset_from, visionset_to, visionset_type = VSMGR_VISIONSET_TYPE_NAKED ) {}

function register_overlay_info_style_none( name, version, lerp_step_count ) {}

function register_overlay_info_style_filter( name, version, lerp_step_count, filter_index, pass_index, material_name, constant_index ) {}

function register_overlay_info_style_blur( name, version, lerp_step_count, transition_in, transition_out, magnitude ) {}

function register_overlay_info_style_electrified( name, version, lerp_step_count, duration ) {}

function register_overlay_info_style_burn( name, version, lerp_step_count, duration ) {}

function register_overlay_info_style_poison( name, version, lerp_step_count ) {}

function register_overlay_info_style_transported( name, version, lerp_step_count, duration ) {}

// Speed blur duration is managed outside of visionset_mgr
function register_overlay_info_style_speed_blur( name, version, lerp_step_count, amount, inner_radius, outer_radius, velocity_should_scale, velocity_scale, blur_in, blur_out, should_offset ) {}

function register_overlay_info_style_postfx_bundle( name, version, lerp_step_count, bundle, duration ) {}


