// Opening cinematic for "낙찰! 나라장터 생존기".
// Stages the four rooms and both mascots exported from the Godot game
// (build/unity_export/*.glb, imported with glTFast), animates a perspective
// camera through five shots and renders 1920x1080 PNG frames.
// Run: Unity -batchmode -projectPath unity_cinematic -executeMethod CinematicRenderer.Render -quit
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

public static class CinematicRenderer
{
    const int Width = 1920;
    const int Height = 1080;
    const int Fps = 30;
    const float RoomSpacing = 30f;

    struct Shot
    {
        public float start, end;
        public int room;
        public Vector3 camFrom, camTo, lookFrom, lookTo;
        public float fov;
        public string step, caption;
    }

    // Positions are in the Godot game's coordinates (x right, -z back wall).
    static readonly Shot[] Shots =
    {
        new Shot { start = 0f, end = 4.2f, room = 0, fov = 34,
            camFrom = new Vector3(0.4f, 7.0f, 7.4f), camTo = new Vector3(1.0f, 3.4f, 4.2f),
            lookFrom = new Vector3(0.3f, 0.4f, -0.6f), lookTo = new Vector3(0.5f, 0.7f, -1.1f),
            step = "EP01", caption = "시청 · 공정한 구매 규격을 정하고" },
        new Shot { start = 4.2f, end = 8.2f, room = 1, fov = 36,
            camFrom = new Vector3(-2.6f, 2.7f, 3.9f), camTo = new Vector3(2.4f, 2.7f, 3.9f),
            lookFrom = new Vector3(-1.6f, 0.7f, -1.4f), lookTo = new Vector3(2.0f, 0.7f, -0.4f),
            step = "EP01", caption = "업체 · 공고와 원가를 살펴 전자입찰" },
        new Shot { start = 8.2f, end = 11.8f, room = 2, fov = 34,
            camFrom = new Vector3(1.0f, 3.6f, 5.6f), camTo = new Vector3(1.3f, 2.2f, 3.0f),
            lookFrom = new Vector3(1.2f, 0.8f, -1.4f), lookTo = new Vector3(1.4f, 0.9f, -1.6f),
            step = "EP01", caption = "조달청 · 사실대로 적격심사" },
        new Shot { start = 11.8f, end = 15.4f, room = 3, fov = 36,
            camFrom = new Vector3(-3.4f, 2.3f, 3.4f), camTo = new Vector3(2.4f, 2.3f, 3.4f),
            lookFrom = new Vector3(-3.1f, 0.7f, -1.7f), lookTo = new Vector3(2.0f, 0.7f, -1.7f),
            step = "EP02", caption = "종합쇼핑몰 · 가격과 납기, 판매 전략으로 손익을" },
        new Shot { start = 15.4f, end = 21.0f, room = 0, fov = 30,
            camFrom = new Vector3(-0.25f, 1.25f, 4.2f), camTo = new Vector3(-0.25f, 1.0f, 3.1f),
            lookFrom = new Vector3(-0.25f, 0.5f, 0.8f), lookTo = new Vector3(-0.25f, 0.5f, 0.8f),
            step = "", caption = "" },
    };

    static readonly string[] Rooms = { "room_city", "room_office", "room_review", "room_showroom" };

    static Vector3 G(Vector3 godot, int room)
    {
        // glTFast converts glTF's right-handed space by mirroring X.
        return new Vector3(-godot.x + room * RoomSpacing, godot.y, godot.z);
    }

    [MenuItem("Nakchal/Render Opening Cinematic")]
    public static void Render()
    {
        AssetDatabase.Refresh();
        EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        SetupLighting();

        var font = AssetDatabase.LoadAssetAtPath<Font>("Assets/Fonts/Pretendard-Bold.otf");
        SignMeshes.Clear();
        var mascots = new GameObject[Rooms.Length, 2];
        for (int r = 0; r < Rooms.Length; r++)
        {
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>($"Assets/Imported/{Rooms[r]}.glb");
            var room = Object.Instantiate(prefab);
            room.transform.position = new Vector3(r * RoomSpacing, 0, 0);
            TameEmission(room);
            AddSign(font, Signs[r], G(SignPos[r], r));
            var spot = r == 0 ? new Vector3(-0.6f, 0, 0.8f) : new Vector3(-0.3f, 0, 1.6f);
            mascots[r, 0] = Spawn("mascot_nareumi", G(spot, r));
            mascots[r, 1] = Spawn("mascot_dali", G(spot + new Vector3(0.68f, 0, 0.15f), r));
        }

        var camGo = new GameObject("CinematicCamera");
        var cam = camGo.AddComponent<Camera>();
        cam.backgroundColor = new Color(0.1f, 0.14f, 0.15f);
        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.nearClipPlane = 0.05f;
        cam.farClipPlane = 80f;
        cam.allowMSAA = true;

        var overlay = new Overlay(cam, font);

        var rt = new RenderTexture(Width, Height, 24, RenderTextureFormat.ARGB32) { antiAliasing = 8 };
        var tex = new Texture2D(Width, Height, TextureFormat.RGB24, false);
        string outDir = Path.GetFullPath(Path.Combine(Application.dataPath, "../../build/unity_frames"));
        Directory.CreateDirectory(outDir);
        foreach (var f in Directory.GetFiles(outDir, "frame_*.png")) File.Delete(f);

        float total = Shots[Shots.Length - 1].end;
        int frames = Mathf.CeilToInt(total * Fps);
        for (int i = 0; i < frames; i++)
        {
            float t = i / (float)Fps;
            var shot = Shots[0];
            foreach (var s in Shots) if (t >= s.start && t < s.end) shot = s;
            float p = Mathf.InverseLerp(shot.start, shot.end, t);
            float e = p * p * (3f - 2f * p);
            cam.fieldOfView = shot.fov;
            cam.transform.position = G(Vector3.Lerp(shot.camFrom, shot.camTo, e), shot.room);
            cam.transform.LookAt(G(Vector3.Lerp(shot.lookFrom, shot.lookTo, e), shot.room));

            AnimateMascots(mascots, t, shot);
            bool final = shot.caption.Length == 0;
            float fade = Mathf.Clamp01(Mathf.Min(t - shot.start, shot.end - t) / 0.35f);
            if (t < 0.4f) fade = Mathf.Clamp01(t / 0.4f);
            for (int si = 0; si < SignMeshes.Count; si++)
            {
                var keep = SignMeshes[si].text;
                SignMeshes[si].text = "";
                SignMeshes[si].text = keep;
            }
            overlay.Layout(cam);
            overlay.Update(shot.step, shot.caption, final, t - shot.start, fade);

            cam.targetTexture = rt;
            cam.Render();
            RenderTexture.active = rt;
            tex.ReadPixels(new Rect(0, 0, Width, Height), 0, 0);
            tex.Apply();
            File.WriteAllBytes(Path.Combine(outDir, $"frame_{i:D5}.png"), tex.EncodeToPNG());
        }
        RenderTexture.active = null;
        cam.targetTexture = null;
        Debug.Log($"CINEMATIC rendered {frames} frames to {outDir}");
    }

    // Room name plates (3D text does not survive the glTF export).
    static readonly string[] Signs = { "○○시청 계약과 · 구매 규격 검토실", "한빛퍼니처 · 대표 사무실", "조달청 · 적격심사실", "나라장터 종합쇼핑몰 · 회의용 탁자" };
    static readonly Vector3[] SignPos = { new Vector3(0.9f, 1.86f, -2.955f), new Vector3(0.6f, 1.86f, -3.055f), new Vector3(1.3f, 1.86f, -2.955f), new Vector3(0f, 1.86f, -3.055f) };

    static readonly System.Collections.Generic.List<TextMesh> SignMeshes = new System.Collections.Generic.List<TextMesh>();

    static void AddSign(Font font, string text, Vector3 pos)
    {
        var go = new GameObject("Sign");
        go.transform.position = pos;
        go.transform.rotation = Quaternion.Euler(0, 180f, 0);
        var tm = go.AddComponent<TextMesh>();
        tm.font = font;
        tm.fontSize = 96;
        tm.characterSize = 0.02f;
        tm.anchor = TextAnchor.MiddleCenter;
        tm.color = new Color(0.98f, 0.96f, 0.92f);
        tm.text = text;
        go.GetComponent<MeshRenderer>().sharedMaterial = font.material;
        SignMeshes.Add(tm);
    }

    // Screens use emissive materials that read too hot under Unity's lighting.
    static void TameEmission(GameObject root)
    {
        foreach (var r in root.GetComponentsInChildren<Renderer>())
        {
            foreach (var m in r.sharedMaterials)
            {
                if (m == null) continue;
                foreach (var prop in new[] { "_EmissionColor", "emissiveFactor" })
                {
                    if (m.HasProperty(prop))
                    {
                        var c = m.GetColor(prop);
                        if (c.maxColorComponent > 0.01f) m.SetColor(prop, c * 0.35f);
                    }
                }
            }
        }
    }

    static GameObject Spawn(string name, Vector3 pos)
    {
        var prefab = AssetDatabase.LoadAssetAtPath<GameObject>($"Assets/Imported/{name}.glb");
        var go = Object.Instantiate(prefab);
        go.transform.position = pos;
        go.transform.rotation = Quaternion.Euler(0, 180f, 0);
        go.transform.localScale = Vector3.one * 0.86f;
        return go;
    }

    static void AnimateMascots(GameObject[,] mascots, float t, Shot shot)
    {
        for (int r = 0; r < mascots.GetLength(0); r++)
        {
            for (int k = 0; k < 2; k++)
            {
                var m = mascots[r, k];
                var basePos = m.transform.position;
                float phase = k * 0.9f + r;
                float hop = shot.caption.Length == 0 && r == 0
                    ? Mathf.Abs(Mathf.Sin((t - shot.start) * 5.2f + phase)) * 0.12f
                    : Mathf.Abs(Mathf.Sin(t * 2.4f + phase)) * 0.025f;
                m.transform.position = new Vector3(basePos.x, hop, basePos.z);
                m.transform.rotation = Quaternion.Euler(0, Mathf.Sin(t * 1.3f + phase) * 12f, Mathf.Sin(t * 5.2f + phase) * 3f);
            }
        }
    }

    static void SetupLighting()
    {
        RenderSettings.ambientMode = AmbientMode.Trilight;
        RenderSettings.ambientSkyColor = new Color(0.78f, 0.82f, 0.86f) * 0.8f;
        RenderSettings.ambientEquatorColor = new Color(0.62f, 0.58f, 0.52f) * 0.7f;
        RenderSettings.ambientGroundColor = new Color(0.35f, 0.3f, 0.26f) * 0.6f;
        RenderSettings.fog = false;
        QualitySettings.shadows = ShadowQuality.All;
        QualitySettings.shadowResolution = ShadowResolution.VeryHigh;
        QualitySettings.shadowDistance = 30f;
        QualitySettings.antiAliasing = 8;
        var key = new GameObject("Key").AddComponent<Light>();
        key.type = LightType.Directional;
        key.color = new Color(1f, 0.94f, 0.86f);
        key.intensity = 1.05f;
        key.shadows = LightShadows.Soft;
        key.shadowStrength = 0.7f;
        key.transform.rotation = Quaternion.Euler(52f, 32f, 0f);
        var fill = new GameObject("Fill").AddComponent<Light>();
        fill.type = LightType.Directional;
        fill.color = new Color(0.72f, 0.8f, 0.9f);
        fill.intensity = 0.3f;
        fill.transform.rotation = Quaternion.Euler(30f, -150f, 0f);
        for (int r = 0; r < Rooms.Length; r++)
        {
            var warm = new GameObject("RoomGlow").AddComponent<Light>();
            warm.type = LightType.Point;
            warm.color = new Color(1f, 0.85f, 0.65f);
            warm.intensity = 0.8f;
            warm.range = 6f;
            warm.transform.position = G(new Vector3(0.5f, 2.3f, 0.2f), r);
        }
    }

    // Captions and title drawn with 3D text parented to the camera.
    class Overlay
    {
        readonly TextMesh step, caption, title, subtitle;
        readonly Renderer bar, shade;
        readonly Material barMat, shadeMat;

        public Overlay(Camera cam, Font font)
        {
            var shader = Shader.Find("Sprites/Default");
            barMat = new Material(shader) { color = new Color(0.09f, 0.19f, 0.23f, 0.85f) };
            shadeMat = new Material(shader) { color = new Color(0.08f, 0.15f, 0.17f, 0f) };
            bar = Quad(cam, new Vector3(0f, -0.33f, 1.2f), new Vector3(1.6f, 0.13f, 1f), barMat);
            shade = Quad(cam, new Vector3(0, 0, 1.25f), new Vector3(3f, 2f, 1f), shadeMat);
            step = Text(cam, font, new Vector3(-0.72f, -0.33f, 1.19f), 0.0024f, new Color(0.88f, 0.48f, 0.21f), TextAnchor.MiddleLeft);
            caption = Text(cam, font, new Vector3(-0.6f, -0.33f, 1.19f), 0.0026f, new Color(0.98f, 0.96f, 0.92f), TextAnchor.MiddleLeft);
            title = Text(cam, font, new Vector3(0, 0.28f, 1.19f), 0.0052f, new Color(0.98f, 0.96f, 0.92f), TextAnchor.MiddleCenter);
            subtitle = Text(cam, font, new Vector3(0, 0.18f, 1.19f), 0.0024f, new Color(1f, 0.78f, 0.55f), TextAnchor.MiddleCenter);
        }

        static Renderer Quad(Camera cam, Vector3 local, Vector3 scale, Material mat)
        {
            var q = GameObject.CreatePrimitive(PrimitiveType.Quad);
            Object.DestroyImmediate(q.GetComponent<Collider>());
            q.transform.SetParent(cam.transform, false);
            q.transform.localPosition = local;
            q.transform.localScale = scale;
            var r = q.GetComponent<Renderer>();
            r.sharedMaterial = mat;
            r.shadowCastingMode = ShadowCastingMode.Off;
            return r;
        }

        static TextMesh Text(Camera cam, Font font, Vector3 local, float size, Color color, TextAnchor anchor)
        {
            var go = new GameObject("Text");
            go.transform.SetParent(cam.transform, false);
            go.transform.localPosition = local;
            var tm = go.AddComponent<TextMesh>();
            tm.font = font;
            tm.fontSize = 96;
            tm.characterSize = size * 10f;
            tm.anchor = anchor;
            tm.color = color;
            var mr = go.GetComponent<MeshRenderer>();
            mr.sharedMaterial = font.material;
            mr.sortingOrder = 10;
            return tm;
        }

        // Keep overlay elements pinned to screen fractions whatever the FOV.
        public void Layout(Camera cam)
        {
            const float d = 1.2f;
            float halfH = d * Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad);
            float halfW = halfH * cam.aspect;
            float k = halfH / 0.35f;
            bar.transform.localPosition = new Vector3(0, -halfH * 0.8f, d + 0.01f);
            bar.transform.localScale = new Vector3(halfW * 2.2f, halfH * 0.24f, 1f);
            shade.transform.localPosition = new Vector3(0, 0, d + 0.05f);
            shade.transform.localScale = new Vector3(halfW * 2.4f, halfH * 2.4f, 1f);
            step.transform.localPosition = new Vector3(-halfW * 0.9f, -halfH * 0.8f, d);
            caption.transform.localPosition = new Vector3(-halfW * 0.76f, -halfH * 0.8f, d);
            title.transform.localPosition = new Vector3(0, halfH * 0.8f, d);
            subtitle.transform.localPosition = new Vector3(0, halfH * 0.62f, d);
            step.characterSize = 0.0026f * k;
            caption.characterSize = 0.0026f * k;
            title.characterSize = 0.0062f * k;
            subtitle.characterSize = 0.0028f * k;
        }

        public void Update(string stepText, string captionText, bool final, float local, float fade)
        {
            bool showBar = !final;
            bar.enabled = showBar;
            step.text = showBar ? stepText : "";
            caption.text = showBar ? captionText : "";
            var c = barMat.color; c.a = 0.85f * fade; barMat.color = c;
            SetAlpha(step, fade);
            SetAlpha(caption, fade);
            float titleIn = final ? Mathf.Clamp01((local - 0.6f) / 0.6f) : 0f;
            title.text = final ? "낙찰! 나라장터 생존기" : "";
            subtitle.text = final ? "나라미·달이와 함께하는 공공조달 업무 체험" : "";
            SetAlpha(title, titleIn);
            SetAlpha(subtitle, titleIn);
            var s = shadeMat.color;
            s.a = final ? 0.4f * titleIn + (1f - fade) * 0.6f : (1f - fade);
            shadeMat.color = s;
        }

        static void SetAlpha(TextMesh tm, float a)
        {
            var c = tm.color; c.a = a; tm.color = c;
        }
    }
}
