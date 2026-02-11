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
    [Range(0f, 1f)]
    public float smoothing = 0.1f;
    [Range(0, 1)]
    public int testParam = 0;

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
        int kernel = pathTracingCS.FindKernel("CSMain");
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
        pathTracingCS.SetFloat("_Param", testParam);

        pathTracingCS.SetInt("_sceneMoving", sceneMoving);
        pathTracingCS.SetInt("_useAccumulation", 1);
        pathTracingCS.SetFloat("_CurrentSample", currentSample);
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
