using UnityEngine;

[RequireComponent(typeof(Camera))]
[ImageEffectAllowedInSceneView]
public class PathTracingMaster : MonoBehaviour {
    public Shader PTShader;
    private Material PTMaterial;
    private Camera cam;
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

    [Header("Progressive Rendering")]
    public bool useProgressive = true;

    private RenderTexture[] accumulationTextures = new RenderTexture[2];
    private int currentRT = 0;
    private int currentSample = 0;
    private int frameIndex = 0;

    void Awake() {
        cam = GetComponent<Camera>();
        camLastPos = transform.position;
        camLastRot = transform.rotation;
        if (sphere1 != null) {
            sphere1LastPos = sphere1.position;
        }
        if (sphere2 != null) {
            sphere2LastPos = sphere2.position;
        }
        smoothingLastVal = smoothing;
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination) {
        if (PTMaterial == null) {
            PTMaterial = new Material(PTShader);
            PTMaterial.hideFlags = HideFlags.HideAndDontSave;
        }

        if (useProgressive) {
            RenderProgressive(source, destination);
        } else {
            RenderDirect(source, destination);
        }

        frameIndex++;
    }

    void RenderProgressive(RenderTexture source, RenderTexture destination) {
        // Ensure RTs are initialized
        for (int i = 0; i < 2; i++) {
            if (accumulationTextures[i] == null ||
                accumulationTextures[i].width != Screen.width ||
                accumulationTextures[i].height != Screen.height) {

                if (accumulationTextures[i] != null)
                    accumulationTextures[i].Release();

                accumulationTextures[i] = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
                accumulationTextures[i].enableRandomWrite = true;
                accumulationTextures[i].Create();
                Graphics.Blit(Texture2D.blackTexture, accumulationTextures[i]);
            }
        }

        //check cam movement
        if (camLastPos != transform.position || camLastRot != transform.rotation || sphere1.position != sphere1LastPos || sphere2.position != sphere2LastPos || smoothing != smoothingLastVal) {
            sceneMoving = 1;
            currentSample = 0;
        } else {
            sceneMoving = 0;
        }
        camLastPos = transform.position;
        camLastRot = transform.rotation;
        sphere1LastPos = sphere1.position;
        sphere2LastPos = sphere2.position;
        smoothingLastVal = smoothing;

        int prevRT = 1 - currentRT;

        SetShaderParameters();
        PTMaterial.SetInt("_camMoving", sceneMoving);
        PTMaterial.SetInt("_UseAccumulation", 1);
        PTMaterial.SetFloat("_CurrentSample", currentSample);
        PTMaterial.SetTexture("_PreviousFrame", accumulationTextures[prevRT]);

        // Render current frame into current RT
        Graphics.Blit(source, accumulationTextures[currentRT], PTMaterial);

        // Output to screen
        Graphics.Blit(accumulationTextures[currentRT], destination);

        // Swap RTs for next frame
        currentRT = prevRT;
        currentSample++;
    }

    void RenderDirect(RenderTexture source, RenderTexture destination) {
        SetShaderParameters();
        PTMaterial.SetInt("_UseAccumulation", 0);
        Graphics.Blit(source, destination, PTMaterial);
    }

    void SetShaderParameters() {
        PTMaterial.SetMatrix("_CameraToWorld", cam.cameraToWorldMatrix);
        PTMaterial.SetMatrix("_CameraInverseProjection", cam.projectionMatrix.inverse);

        PTMaterial.SetVector("_Sphere1", sphere1.position);
        PTMaterial.SetVector("_Sphere2", sphere2.position);

        PTMaterial.SetInt("_SAMPLES", samplesPerPixel);
        PTMaterial.SetInt("_BOUNCES", maxBounces);
        PTMaterial.SetInt("_FrameIndex", frameIndex);
        PTMaterial.SetFloat("_Smoothing", smoothing);
        PTMaterial.SetFloat("_Param", testParam);
    }

    public void ResetProgressive() {
        currentSample = 0;
        currentRT = 0;
    }

    void OnDestroy() {
        for (int i = 0; i < 2; i++) {
            if (accumulationTextures[i] != null) {
                accumulationTextures[i].Release();
            }
        }
    }
}
