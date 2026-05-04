# Raymarched Path Tracer

This is a PBR path tracer that uses raymarching instead of raytracing. This allows for rendering of implicitly defined surfaces, which includes fractals and SDFs.

## Features

Most nobable is an implementation of Segment Tracing (Galin et al. 2020). This reduces iterations significantly, although some challenges with estimating the lipschitz bounds arise. 

Other features include Next Event Estimation, Multiple Importance Sampling, Fresnel specular / Lambertian material properties, editable orbit traps for fully customizable fractal coloring, depth of field / AA, and smooth minimum for SDF blending.

## Sample Renders
<img width="3840" alt="Image Sequence_013_0400" src="https://github.com/user-attachments/assets/a0333510-a970-4d6a-b91e-171ccaa57e38" />
<img width="3840" alt="Image Sequence_011_1000" src="https://github.com/user-attachments/assets/993014a6-45e5-4116-abe0-d572dbc3bc16" />
<img width="3840" alt="Image Sequence_015_0400" src="https://github.com/user-attachments/assets/dba2aac1-08b3-47c2-aece-a07cbfaa54ff" />

### Segment tracing / Sphere tracing comparison
#### A redder color is equivalent to a large number of iterations, while a bluer color is equivalent to a small amount of iterations.
Segment tracing:
<img width="1920" alt="Image Sequence_022_0005" src="https://github.com/user-attachments/assets/389f0cdf-6ea2-4a0e-a6d2-b709436d898d" />
Sphere tracing:
<img width="1920" alt="Image Sequence_021_0005" src="https://github.com/user-attachments/assets/d4403bdd-bfa5-44ed-92f1-58fcc9067271" />

All fractals from https://jbaker.graphics/writings/DEC.html
