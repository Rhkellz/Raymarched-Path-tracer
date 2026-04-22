using UnityEngine;

[RequireComponent(typeof(Camera))]
[ImageEffectAllowedInSceneView]
public class PathTracingCompute : MonoBehaviour {
    public ComputeShader pathTracingCS;

    private Camera cam;

    private RenderTexture[] accumulationTextures = new RenderTexture[2];
    private int currentRT = 0;
    private int currentSample = 0;
    private int frameIndex = 0;

    private Vector3 camLastPos;
    private Quaternion camLastRot;
    private Vector3 sphere1LastPos;
    private Vector3 sphere2LastPos;
    private float smoothingLastVal;
    private int sceneMoving = 0;

    [Header("Scene Objects")]
    public Transform sphere1;
    public Transform sphere2;

    [Header("Render Settings")]
    [Range(1, 100)]
    public int samplesPerPixel = 1;
    [Range(1, 100)]
    public int maxBounces = 4;
    [Range(0f, 0.2f)]
    public float smoothing = 0.1f;
    public bool segment_trace = true;
    [Range(1, 32)]
    public int samples_per_segment = 3;
    [Range(0.1f, 10.0f)]
    public float kappa = 2.0f;
    [Range(0.01f, 1f)]
    public float focal_length = 0.01f;
    [Range(0.00f, 5f)]
    public float Defocus = 1.0f;

    [Range(0.00f, 5f)]
    public float AA_jitter = 1.0f;

    public Color BG_color = new Color(0.1f, 0.1f, 0.1f);

    public Color color_1 = new Color(1.0f, 1.0f, 1.0f);
    public Vector3 orbit_1 = new Vector3(0f, 0f, 0f);
    public float radius_1 = 0.3f;

    public Color color_2 = new Color(1.0f, 1.0f, 1.0f);
    public Vector3 orbit_2 = new Vector3(0.1f, 0.1f, 0.1f);
    public float radius_2 = 0.3f;

    public Color color_3 = new Color(1.0f, 1.0f, 1.0f);
    public Vector3 orbit_3 = new Vector3(-0.1f, -0.1f, -0.1f);
    public float radius_3 = 0.3f;

    [Range(0.01f, 20f)]
    public float orbit_sharpness = 8.0f;

    public bool useAccumulation = true;

    void Awake() {
        cam = GetComponent<Camera>();
        camLastPos = transform.position;
        camLastRot = transform.rotation;
        if (sphere1) sphere1LastPos = sphere1.position;
        if (sphere2) sphere2LastPos = sphere2.position;
        smoothingLastVal = smoothing;
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination) {
        InitRenderTextures();

        // Check for camera or scene movement
        if (camLastPos != transform.position || camLastRot != transform.rotation ||
            sphere1.position != sphere1LastPos || sphere2.position != sphere2LastPos ||
            smoothing != smoothingLastVal) {
            sceneMoving = 1;
            currentSample = 0;
        } else sceneMoving = 0;

        camLastPos = transform.position;
        camLastRot = transform.rotation;
        sphere1LastPos = sphere1.position;
        sphere2LastPos = sphere2.position;
        smoothingLastVal = smoothing;

        int prevRT = 1 - currentRT;

        // Set all compute shader parameters
        SetShaderParameters(accumulationTextures[prevRT]);

        // Dispatch compute shader
        int kernel = pathTracingCS.FindKernel("CSRewrite");
        int threadGroupsX = Mathf.CeilToInt(Screen.width / 8.0f);
        int threadGroupsY = Mathf.CeilToInt(Screen.height / 8.0f);
        pathTracingCS.Dispatch(kernel, threadGroupsX, threadGroupsY, 1);

        // Blit to screen
        Graphics.Blit(accumulationTextures[currentRT], destination);

        // Swap RTs
        currentRT = prevRT;
        currentSample++;
        frameIndex++;
    }

    void InitRenderTextures() {
        for (int i = 0; i < 2; i++) {
            if (accumulationTextures[i] == null ||
                accumulationTextures[i].width != Screen.width ||
                accumulationTextures[i].height != Screen.height) {
                if (accumulationTextures[i] != null)
                    accumulationTextures[i].Release();

                accumulationTextures[i] = new RenderTexture(Screen.width, Screen.height, 0,
                    RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
                accumulationTextures[i].enableRandomWrite = true;
                accumulationTextures[i].Create();
            }
        }
    }

    void SetShaderParameters(RenderTexture prevFrame) {
        pathTracingCS.SetTexture(0, "Result", accumulationTextures[currentRT]);
        pathTracingCS.SetTexture(0, "_PreviousFrame", prevFrame);

        pathTracingCS.SetInt("_Width", Screen.width);
        pathTracingCS.SetInt("_Height", Screen.height);

        pathTracingCS.SetMatrix("_CameraToWorld", cam.cameraToWorldMatrix);
       pathTracingCS.SetMatrix("_CameraInverseProjection", cam.projectionMatrix.inverse);

        pathTracingCS.SetVector("_Sphere1", sphere1.position);
        pathTracingCS.SetVector("_Sphere2", sphere2.position);

        pathTracingCS.SetInt("_SAMPLES", samplesPerPixel);
        pathTracingCS.SetInt("_BOUNCES", maxBounces);
        pathTracingCS.SetInt("_FrameIndex", frameIndex);
        pathTracingCS.SetFloat("_Smoothing", smoothing);
        pathTracingCS.SetFloat("_Focal_len", focal_length);
        pathTracingCS.SetFloat("_Defocus", Defocus);

        pathTracingCS.SetVector("_color_1", color_1);
        pathTracingCS.SetVector("_orbit_1", orbit_1);
        pathTracingCS.SetFloat("_rad_1", radius_1);

        pathTracingCS.SetVector("_color_2", color_2);
        pathTracingCS.SetVector("_orbit_2", orbit_2);
        pathTracingCS.SetFloat("_rad_2", radius_2);

        pathTracingCS.SetVector("_color_3", color_3);
        pathTracingCS.SetVector("_orbit_3", orbit_3);
        pathTracingCS.SetFloat("_rad_3", radius_3);

        pathTracingCS.SetVector("_bg_col", BG_color);

        pathTracingCS.SetFloat("_orbit_sharp", orbit_sharpness);
        pathTracingCS.SetFloat("_AA_jitter", AA_jitter);

        pathTracingCS.SetInt("_sceneMoving", sceneMoving);
        pathTracingCS.SetFloat("_CurrentSample", currentSample);
        pathTracingCS.SetFloat("_kappa", kappa);

        pathTracingCS.SetInt("_samples_per_segment", samples_per_segment);
        if (segment_trace) {
            pathTracingCS.SetInt("_use_segment", 1);
        } else {
            pathTracingCS.SetInt("_use_segment", 0);
        }
        
        if (useAccumulation) {
            pathTracingCS.SetInt("_useAccumulation", 1);
        } else {
            pathTracingCS.SetInt("_useAccumulation", 0);
        }
    }

    void OnDestroy() {
        for (int i = 0; i < 2; i++)
            if (accumulationTextures[i] != null)
                accumulationTextures[i].Release();
    }
}
