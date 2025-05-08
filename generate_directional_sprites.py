#!/usr/bin/env python3

import os
import sys
import subprocess
import shutil

# Ensure the directory exists
def ensure_dir(directory):
    if not os.path.exists(directory):
        os.makedirs(directory)

# Get image dimensions
def get_image_dimensions(image_path):
    info_output = subprocess.check_output(["magick", "identify", "-format", "%w %h", image_path]).decode("utf-8").strip()
    width, height = map(int, info_output.split())
    return width, height

# Extract individual frames from a sprite sheet (7x2 layout)
def extract_frames(input_file, output_dir):
    width, height = get_image_dimensions(input_file)
    
    # Determine frame size based on 7x2 layout
    frame_width = width / 7
    frame_height = height / 2
    
    # Extract all 14 frames
    for i in range(14):
        row = i // 7
        col = i % 7
        x_offset = col * frame_width
        y_offset = row * frame_height
        
        subprocess.run([
            "magick", input_file,
            "-crop", f"{frame_width}x{frame_height}+{x_offset}+{y_offset}",
            "+repage",
            os.path.join(output_dir, f"frame_{i:02d}.png")
        ])

# Assemble frames into a sprite sheet with exact dimensions of the original
def assemble_frames(input_dir, output_file, reference_file):
    orig_width, orig_height = get_image_dimensions(reference_file)
    
    # Create the montage with consistent dimensions
    subprocess.run([
        "magick", "montage",
        os.path.join(input_dir, "frame_*.png"),
        "-tile", "7x2",
        "-background", "none",
        "-geometry", "+0+0",
        # "-resize", f"{orig_width}x{orig_height}!",
        output_file
    ])
    
    # Verify the output dimensions match the original
    # out_width, out_height = get_image_dimensions(output_file)
    # if out_width != orig_width or out_height != orig_height:
    #     print(f"WARNING: Output dimensions ({out_width}x{out_height}) don't match original ({orig_width}x{orig_height})")
    #     print(f"Forcing resize of {output_file}")
    #     subprocess.run([
    #         "magick", output_file,
    #         "-resize", f"{orig_width}x{orig_height}!",
    #         output_file
    #     ])

# Main directories
graphics_dir = "graphics"
types = ["normal", "fast", "express", "turbo"]
directions = ["north", "east", "south", "west"]

# Create directories for each type and direction
for type_name in types:
    type_dir = os.path.join(graphics_dir, type_name)
    ensure_dir(type_dir)
    # Create direction subdirectories
    for direction in directions:
        dir_path = os.path.join(type_dir, direction)
        ensure_dir(dir_path)

# Original sprite files
files = ["input.png", "output.png", "input-shadow.png", "output-shadow.png"]

# First, process normal sprites for all directions
normal_dir = os.path.join(graphics_dir, "normal")
for file in files:
    source_file = os.path.join(normal_dir, file)
    
    if not os.path.exists(source_file):
        print(f"Error: {source_file} does not exist!")
        continue
    
    # Get original dimensions for reference
    orig_width, orig_height = get_image_dimensions(source_file)
    print(f"Original dimensions for {file}: {orig_width}x{orig_height}")
    
    # WEST - No rotation (original direction)
    west_file = os.path.join(normal_dir, "west", file)
    print(f"Creating {west_file}")
    subprocess.run(["magick", source_file, west_file])
    
    # EAST - Horizontal flip of west (mirrored)
    east_file = os.path.join(normal_dir, "east", file)
    print(f"Creating {east_file}")
    subprocess.run([
        "magick", source_file, 
        "-flop", 
        east_file
    ])
    
    # Verify dimensions are unchanged
    east_width, east_height = get_image_dimensions(east_file)
    west_width, west_height = get_image_dimensions(west_file)
    
    # if east_width != orig_width or east_height != orig_height:
    #     print(f"WARNING: East dimensions don't match original, fixing")
    #     subprocess.run(["magick", east_file, "-resize", f"{orig_width}x{orig_height}!", east_file])
    
    # if west_width != orig_width or west_height != orig_height:
    #     print(f"WARNING: West dimensions don't match original, fixing")
    #     subprocess.run(["magick", west_file, "-resize", f"{orig_width}x{orig_height}!", west_file])
        
    # NORTH - Create from individual rotated frames
    north_file = os.path.join(normal_dir, "north", file)
    print(f"Creating {north_file}")
    
    # Create temp directories
    west_frames_dir = f"temp_west_frames_{file}"
    north_frames_dir = f"temp_north_frames_{file}"
    ensure_dir(west_frames_dir)
    ensure_dir(north_frames_dir)
    
    try:
        # Extract frames from west file
        extract_frames(west_file, west_frames_dir)
        
        # Rotate each frame 90 degrees and flip horizontally
        for i in range(14):
            frame_file = os.path.join(west_frames_dir, f"frame_{i:02d}.png")
            rotated_file = os.path.join(north_frames_dir, f"frame_{i:02d}.png")
            subprocess.run([
                "magick", frame_file,
                "-rotate", "90",
                "-flop",  # Add horizontal flip
                rotated_file
            ])
        
        # Assemble rotated frames into north file with exact dimensions
        assemble_frames(north_frames_dir, north_file, source_file)
        
    finally:
        # Clean up temp directories
        if os.path.exists(west_frames_dir):
            shutil.rmtree(west_frames_dir)
        if os.path.exists(north_frames_dir):
            shutil.rmtree(north_frames_dir)
    
    # SOUTH - Flip north sprites vertically
    south_file = os.path.join(normal_dir, "south", file)
    print(f"Creating {south_file}")
    subprocess.run([
        "magick", north_file,
        "-flip",  # Vertical flip
        south_file
    ])
    
    # Final dimension check and fix for north/south
    # north_width, north_height = get_image_dimensions(north_file)
    # if north_width != orig_width or north_height != orig_height:
    #     print(f"WARNING: North dimensions don't match original, fixing")
    #     subprocess.run(["magick", north_file, "-resize", f"{orig_width}x{orig_height}!", north_file])
    
    # south_width, south_height = get_image_dimensions(south_file)
    # if south_width != orig_width or south_height != orig_height:
    #     print(f"WARNING: South dimensions don't match original, fixing")
    #     subprocess.run(["magick", south_file, "-resize", f"{orig_width}x{orig_height}!", south_file])
    
    # Final verification
    for direction in directions:
        dir_file = os.path.join(normal_dir, direction, file)
        width, height = get_image_dimensions(dir_file)
        print(f"Final {direction} dimensions: {width}x{height}")

# Now generate color variants for fast, express, and turbo
print("\nGenerating color variants...")
# HSL modulation values for each type
type_colors = {
    "express": {"hue": 200, "saturation": 100, "lightness": 0},
    "fast": {"hue": 75, "saturation": 100, "lightness": 0},
    "turbo": {"hue": 120, "saturation": 100, "lightness": 0}
}

# Skip shadow files for HSL modulation
non_shadow_files = [f for f in files if "shadow" not in f]

# For each variant type
for type_name, color_settings in type_colors.items():
    print(f"\nGenerating {type_name} variants...")
    type_dir = os.path.join(graphics_dir, type_name)
    
    # For each direction
    for direction in directions:
        # For each file
        for file in files:
            source_file = os.path.join(normal_dir, direction, file)
            target_file = os.path.join(type_dir, direction, file)
            
            if "shadow" in file:
                # Simply copy shadow files without color modification
                print(f"Copying shadow file: {target_file}")
                subprocess.run(["magick", source_file, target_file])
            else:
                # Apply HSL modulation for non-shadow files
                print(f"Creating colored variant: {target_file}")
                hue = color_settings["hue"]
                saturation = color_settings["saturation"]
                lightness = color_settings["lightness"]
                
                subprocess.run([
                    "magick", source_file,
                    "-modulate", f"100,100,{hue}",  # Adjust hue
                    "-fill", f"hsl({hue},{saturation}%,{lightness}%)", 
                    "-colorize", "20",  # Blend with color
                    target_file
                ])
                
            # Verify dimensions
            # width, height = get_image_dimensions(target_file)
            # orig_width, orig_height = get_image_dimensions(source_file)
            # if width != orig_width or height != orig_height:
            #     print(f"WARNING: {type_name} {direction} dimensions don't match original, fixing")
            #     subprocess.run(["magick", target_file, "-resize", f"{orig_width}x{orig_height}!", target_file])

# Clean up old directories if they exist
for direction in directions:
    old_dir = os.path.join(graphics_dir, direction)
    if direction in types:
        continue
    if os.path.exists(old_dir):
        print(f"Removing old directory: {old_dir}")
        shutil.rmtree(old_dir)

print("All sprites generated successfully!") 