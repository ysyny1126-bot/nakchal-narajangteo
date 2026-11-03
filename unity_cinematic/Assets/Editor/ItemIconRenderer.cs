// Shop item icons for "조달청 사원 키우기".
// Builds each office item from soft procedural meshes (rounded boxes, lathed
// profiles, tori), lights it like a toy and renders a transparent 320x320 PNG
// into the Godot project (assets/items/<id>.png). Ids match scripts/core/shop_items.gd.
// Run: Unity -batchmode -projectPath unity_cinematic -executeMethod ItemIconRenderer.Render -quit
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

public static class ItemIconRenderer
{
    const int Size = 320;
    const int Super = 2;

    static readonly Dictionary<Color, Material> Mats = new Dictionary<Color, Material>();

    static readonly Color Navy = Hex("#2b4d63");
    static readonly Color Cream = Hex("#fbf3df");
    static readonly Color Gold = Hex("#e9b949");
    static readonly Color Wood = Hex("#b9784a");
    static readonly Color DarkWood = Hex("#7a4a2c");
    static readonly Color Orange = Hex("#f08a2c");
    static readonly Color Red = Hex("#e05a4a");
    static readonly Color Mint = Hex("#7fcfb5");
    static readonly Color Leaf = Hex("#4fae5b");
    static readonly Color White = Hex("#fffdf8");
    static readonly Color Charcoal = Hex("#3d4750");
    static readonly Color Screen = Hex("#8fd3f0");

    [MenuItem("Nakchal/Render Shop Item Icons")]
    public static void Render()
    {
        EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        // Shadow quality is raised for the icons only; the cinematic keeps its own.
        float oldShadowDistance = QualitySettings.shadowDistance;
        var oldShadowResolution = QualitySettings.shadowResolution;
        SetupLighting();
        var outDir = Path.GetFullPath(Path.Combine(Application.dataPath, "../../assets/items"));
        Directory.CreateDirectory(outDir);

        var cam = new GameObject("IconCam").AddComponent<Camera>();
        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.backgroundColor = new Color(0, 0, 0, 0);
        cam.fieldOfView = 22f;
        cam.nearClipPlane = 0.05f;
        cam.farClipPlane = 50f;
        cam.allowMSAA = true;

        var builders = new (string id, System.Func<GameObject> build)[]
        {
            ("law_book", LawBook), ("highlighter", Highlighter), ("magnifier", Magnifier),
            ("calculator", Calculator), ("stamp", Stamp), ("planner", Planner),
            ("dual_monitor", DualMonitor), ("coffee", Coffee), ("ramen", Ramen),
            ("vitamin", Vitamin), ("tangerine", Tangerine), ("plant", Plant),
            ("lamp", Lamp), ("clock", AlarmClock), ("nameplate", Nameplate), ("trophy", Trophy),
        };
        foreach (var (id, build) in builders)
        {
            var item = build();
            Frame(cam, item);
            var png = Shoot(cam);
            File.WriteAllBytes(Path.Combine(outDir, id + ".png"), png);
            Debug.Log($"ICON {id}");
            Object.DestroyImmediate(item);
        }
        QualitySettings.shadowDistance = oldShadowDistance;
        QualitySettings.shadowResolution = oldShadowResolution;
    }

    // --- Camera / output ------------------------------------------------------

    static void Frame(Camera cam, GameObject item)
    {
        var bounds = new Bounds(item.transform.position, Vector3.zero);
        foreach (var r in item.GetComponentsInChildren<Renderer>())
            bounds.Encapsulate(r.bounds);
        var dir = Quaternion.Euler(24f, -32f, 0f) * Vector3.back;
        float radius = bounds.extents.magnitude;
        float dist = radius / Mathf.Sin(cam.fieldOfView * 0.5f * Mathf.Deg2Rad) * 1.02f;
        cam.transform.position = bounds.center + dir * dist;
        cam.transform.LookAt(bounds.center);
    }

    static byte[] Shoot(Camera cam)
    {
        int big = Size * Super;
        var rt = new RenderTexture(big, big, 24, RenderTextureFormat.ARGB32) { antiAliasing = 8 };
        cam.targetTexture = rt;
        cam.Render();
        RenderTexture.active = rt;
        var src = new Texture2D(big, big, TextureFormat.RGBA32, false);
        src.ReadPixels(new Rect(0, 0, big, big), 0, 0);
        src.Apply();
        RenderTexture.active = null;
        cam.targetTexture = null;
        Object.DestroyImmediate(rt);

        // The clear colour is transparent black, so edge pixels come out
        // premultiplied: average in that space, then un-premultiply.
        var px = src.GetPixels();
        var dst = new Texture2D(Size, Size, TextureFormat.RGBA32, false);
        var outPx = new Color[Size * Size];
        for (int y = 0; y < Size; y++)
        for (int x = 0; x < Size; x++)
        {
            var sum = new Color(0, 0, 0, 0);
            for (int sy = 0; sy < Super; sy++)
            for (int sx = 0; sx < Super; sx++)
                sum += px[(y * Super + sy) * big + x * Super + sx];
            sum /= Super * Super;
            if (sum.a > 0.004f)
                sum = new Color(sum.r / sum.a, sum.g / sum.a, sum.b / sum.a, sum.a);
            else
                sum = new Color(0, 0, 0, 0);
            outPx[y * Size + x] = sum;
        }
        dst.SetPixels(outPx);
        dst.Apply();
        var bytes = dst.EncodeToPNG();
        Object.DestroyImmediate(src);
        Object.DestroyImmediate(dst);
        return bytes;
    }

    static void SetupLighting()
    {
        RenderSettings.ambientMode = AmbientMode.Trilight;
        RenderSettings.ambientSkyColor = Hex("#fff6e6") * 0.78f;
        RenderSettings.ambientEquatorColor = Hex("#e8eef0") * 0.58f;
        RenderSettings.ambientGroundColor = Hex("#c9b8a6") * 0.4f;
        RenderSettings.skybox = null;
        var key = new GameObject("Key").AddComponent<Light>();
        key.type = LightType.Directional;
        key.color = Hex("#fff1dc");
        key.intensity = 1.05f;
        key.shadows = LightShadows.Soft;
        key.shadowStrength = 0.35f;
        key.transform.rotation = Quaternion.Euler(48f, -58f, 0f);
        var rim = new GameObject("Rim").AddComponent<Light>();
        rim.type = LightType.Directional;
        rim.color = Hex("#dff0ff");
        rim.intensity = 0.45f;
        rim.transform.rotation = Quaternion.Euler(20f, 150f, 0f);
        QualitySettings.shadowDistance = 20f;
        QualitySettings.shadowResolution = ShadowResolution.VeryHigh;
    }

    // --- Items ----------------------------------------------------------------

    static GameObject LawBook()
    {
        var root = new GameObject("law_book");
        Book(root, new Vector3(0, 0, 0), new Vector3(1.25f, 0.26f, 0.9f), Hex("#8a3b34"), 8f);
        Book(root, new Vector3(0.04f, 0.27f, 0.02f), new Vector3(1.15f, 0.3f, 0.84f), Navy, -6f);
        var standing = Book(root, new Vector3(-0.15f, 0.56f, 0.05f), new Vector3(1.0f, 0.24f, 0.74f), Hex("#2f7a64"), 14f);
        standing.transform.localRotation = Quaternion.Euler(0, 14f, 0);
        return root;
    }

    static GameObject Book(GameObject parent, Vector3 pos, Vector3 size, Color cover, float yaw)
    {
        var book = Group(parent, "book", pos, new Vector3(0, yaw, 0));
        var t = 0.04f;
        Box(book, new Vector3(0, t * 0.5f, 0), new Vector3(size.x, t, size.z), 0.02f, cover);
        Box(book, new Vector3(0, size.y - t * 0.5f, 0), new Vector3(size.x, t, size.z), 0.02f, cover);
        Box(book, new Vector3(-size.x * 0.5f + 0.03f, size.y * 0.5f, 0), new Vector3(0.07f, size.y, size.z), 0.035f, cover);
        Box(book, new Vector3(0.02f, size.y * 0.5f, 0), new Vector3(size.x - 0.07f, size.y - t * 1.6f, size.z - 0.06f), 0.015f, Cream);
        Box(book, new Vector3(-size.x * 0.5f + 0.0f, size.y * 0.5f, 0), new Vector3(0.075f, size.y * 0.16f, size.z * 1.002f), 0.01f, Gold);
        return book;
    }

    static GameObject Highlighter()
    {
        var root = new GameObject("highlighter");
        var pen = Group(root, "pen", Vector3.zero, new Vector3(0, 0, 62f));
        Lathe(pen, Vector3.zero, new[] { V(0, -0.9f), V(0.16f, -0.9f), V(0.2f, -0.82f), V(0.2f, 0.35f), V(0, 0.35f) }, Hex("#f4e04d"));
        Lathe(pen, Vector3.zero, new[] { V(0, 0.33f), V(0.215f, 0.33f), V(0.215f, 0.88f), V(0.17f, 0.95f), V(0, 0.95f) }, Hex("#8cc63f"));
        Box(pen, new Vector3(0.22f, 0.62f, 0), new Vector3(0.06f, 0.4f, 0.1f), 0.025f, Hex("#8cc63f"));
        Lathe(pen, Vector3.zero, new[] { V(0, -1.12f), V(0.07f, -1.05f), V(0.12f, -0.9f), V(0, -0.9f) }, Hex("#c9e86a"));
        return root;
    }

    static GameObject Magnifier()
    {
        var root = new GameObject("magnifier");
        // Lens axis (Y) faces the icon camera; the inner spin swings the handle down-right.
        var face = Group(root, "face", Vector3.zero, new Vector3(-70f, -32f, 0));
        var g = Group(face, "glass", Vector3.zero, new Vector3(0, -40f, 0));
        Torus(g, Vector3.zero, 0.52f, 0.075f, Navy);
        Lathe(g, Vector3.zero, new[] { V(0, -0.035f), V(0.5f, -0.012f), V(0.5f, 0.012f), V(0, 0.035f) }, Hex("#cdeefc"), 0.85f);
        var shine = Ball(g, new Vector3(-0.18f, 0.04f, 0.16f), new Vector3(0.16f, 0.02f, 0.07f), White);
        shine.transform.localRotation = Quaternion.Euler(0, 40f, 0);
        var handle = Group(g, "handle", new Vector3(0, 0, -0.56f), new Vector3(-90f, 0, 0));
        Lathe(handle, new Vector3(0, 0.12f, 0), new[] { V(0, 0), V(0.06f, 0), V(0.06f, 0.1f), V(0, 0.1f) }, Gold);
        Lathe(handle, new Vector3(0, 0.2f, 0), new[] { V(0, 0), V(0.09f, 0.02f), V(0.11f, 0.7f), V(0.09f, 0.95f), V(0, 0.98f) }, Wood);
        return root;
    }

    static GameObject Calculator()
    {
        var root = new GameObject("calculator");
        var body = Group(root, "body", Vector3.zero, new Vector3(48f, 0, 0));
        Box(body, Vector3.zero, new Vector3(0.95f, 1.35f, 0.16f), 0.07f, Hex("#5c6b78"));
        Box(body, new Vector3(0, 0.44f, -0.07f), new Vector3(0.78f, 0.3f, 0.06f), 0.03f, Hex("#c9e7c4"));
        Box(body, new Vector3(0.12f, 0.44f, -0.1f), new Vector3(0.44f, 0.06f, 0.02f), 0.01f, Hex("#5d7a5a"));
        for (int row = 0; row < 4; row++)
        for (int col = 0; col < 4; col++)
        {
            var c = col == 3 ? (row == 3 ? Orange : Hex("#f6c56b")) : White;
            Box(body, new Vector3(-0.3f + col * 0.2f, 0.12f - row * 0.18f, -0.085f), new Vector3(0.15f, 0.13f, 0.06f), 0.03f, c);
        }
        return root;
    }

    static GameObject Stamp()
    {
        var root = new GameObject("stamp");
        Lathe(root, Vector3.zero, new[] { V(0, 0), V(0.34f, 0), V(0.34f, 0.12f), V(0.3f, 0.16f), V(0, 0.16f) }, Red);
        Lathe(root, Vector3.zero, new[] { V(0, 0.16f), V(0.22f, 0.16f), V(0.15f, 0.3f), V(0.12f, 0.55f), V(0.2f, 0.72f), V(0.21f, 0.82f), V(0.14f, 0.92f), V(0, 0.95f) }, Wood);
        Lathe(root, Vector3.zero, new[] { V(0, 0.2f), V(0.215f, 0.2f), V(0.215f, 0.24f), V(0, 0.24f) }, Gold);
        var pad = Box(root, new Vector3(0.62f, 0.06f, 0.25f), new Vector3(0.62f, 0.12f, 0.46f), 0.05f, Navy);
        Box(root, new Vector3(0.62f, 0.125f, 0.25f), new Vector3(0.5f, 0.02f, 0.36f), 0.01f, Hex("#c2493d"));
        return root;
    }

    static GameObject Planner()
    {
        var root = new GameObject("planner");
        var g = Group(root, "book", Vector3.zero, new Vector3(0, 12f, 0));
        Box(g, new Vector3(0, 0.09f, 0), new Vector3(0.95f, 0.18f, 1.25f), 0.06f, Hex("#3f9c8c"));
        Box(g, new Vector3(0.03f, 0.09f, 0), new Vector3(0.9f, 0.13f, 1.21f), 0.02f, Cream);
        Box(g, new Vector3(0.3f, 0.09f, 0), new Vector3(0.06f, 0.2f, 1.27f), 0.02f, Hex("#f08a2c"));
        Box(g, new Vector3(-0.15f, 0.04f, -0.66f), new Vector3(0.1f, 0.02f, 0.3f), 0.008f, Red);
        Box(g, new Vector3(-0.05f, 0.185f, 0.1f), new Vector3(0.42f, 0.02f, 0.3f), 0.02f, White);
        var pen = Group(root, "pen", new Vector3(0.62f, 0.07f, 0.1f), new Vector3(90f, 18f, 0));
        Lathe(pen, Vector3.zero, new[] { V(0, -0.6f), V(0.05f, -0.52f), V(0.06f, 0.5f), V(0, 0.55f) }, Navy);
        return root;
    }

    static GameObject DualMonitor()
    {
        var root = new GameObject("dual_monitor");
        for (int i = 0; i < 2; i++)
        {
            float side = i == 0 ? -1 : 1;
            var m = Group(root, "mon", new Vector3(side * 0.6f, 0, side * 0.12f), new Vector3(0, -side * 14f, 0));
            Box(m, new Vector3(0, 0.72f, 0), new Vector3(1.12f, 0.72f, 0.08f), 0.05f, Charcoal);
            Box(m, new Vector3(0, 0.73f, -0.042f), new Vector3(1.0f, 0.6f, 0.02f), 0.02f, i == 0 ? Screen : Hex("#bfe7c9"));
            for (int l = 0; l < 3; l++)
                Box(m, new Vector3(-0.15f + (l == 0 ? 0.1f : 0), 0.88f - l * 0.13f, -0.055f), new Vector3(l == 0 ? 0.5f : 0.66f, 0.05f, 0.01f), 0.01f, White);
            Box(m, new Vector3(0, 0.25f, 0.06f), new Vector3(0.1f, 0.42f, 0.06f), 0.03f, Hex("#5c6670"));
            Lathe(m, new Vector3(0, 0, 0.04f), new[] { V(0, 0), V(0.28f, 0), V(0.3f, 0.03f), V(0.26f, 0.06f), V(0, 0.06f) }, Hex("#5c6670"));
        }
        return root;
    }

    static GameObject Coffee()
    {
        var root = new GameObject("coffee");
        Lathe(root, Vector3.zero, new[] { V(0, 0), V(0.3f, 0), V(0.4f, 1.0f), V(0, 1.0f) }, White);
        Lathe(root, Vector3.zero, new[] { V(0, 0.3f), V(0.338f, 0.3f), V(0.372f, 0.68f), V(0, 0.68f) }, Hex("#b98a5b"));
        Lathe(root, Vector3.zero, new[] { V(0, 0.98f), V(0.43f, 0.98f), V(0.43f, 1.05f), V(0.36f, 1.1f), V(0.34f, 1.18f), V(0, 1.2f) }, Hex("#4b3a33"));
        Box(root, new Vector3(0, 0.49f, -0.37f), new Vector3(0.3f, 0.16f, 0.02f), 0.02f, Cream);
        return root;
    }

    static GameObject Ramen()
    {
        var root = new GameObject("ramen");
        Lathe(root, Vector3.zero, new[] { V(0, 0), V(0.34f, 0), V(0.48f, 0.72f), V(0, 0.72f) }, White);
        Lathe(root, Vector3.zero, new[] { V(0, 0.26f), V(0.397f, 0.26f), V(0.437f, 0.5f), V(0, 0.5f) }, Red);
        // Lid peeled back from the front rim so the noodles show.
        var lid = Group(root, "lid", new Vector3(0, 0.72f, -0.4f), new Vector3(-34f, 0, 0));
        Lathe(lid, new Vector3(0, 0, 0.42f), new[] { V(0, 0), V(0.46f, 0), V(0.46f, 0.02f), V(0, 0.02f) }, Hex("#f6c56b"));
        Lathe(root, Vector3.zero, new[] { V(0, 0.64f), V(0.45f, 0.64f), V(0.46f, 0.68f), V(0, 0.68f) }, Hex("#f2d38f"));
        for (int i = 0; i < 7; i++)
        {
            float a = i * 0.9f;
            var curl = Torus(root, new Vector3(Mathf.Cos(a) * 0.22f * (i % 2 + 0.4f), 0.69f, Mathf.Sin(a) * 0.2f), 0.09f, 0.028f, Hex("#f7dc8f"));
            curl.transform.localRotation = Quaternion.Euler(0, i * 37f, 0);
        }
        Ball(root, new Vector3(0.12f, 0.71f, -0.1f), new Vector3(0.12f, 0.03f, 0.12f), Hex("#7cc36b"));
        Ball(root, new Vector3(-0.15f, 0.71f, 0.12f), new Vector3(0.16f, 0.03f, 0.16f), Hex("#f4a6a0"));
        for (int i = 0; i < 2; i++)
        {
            var stick = Group(root, "chopstick", new Vector3(0.18f + i * 0.08f, 0.74f, 0.32f), new Vector3(0, 0, 62f + i * 4f));
            Lathe(stick, Vector3.zero, new[] { V(0, -0.55f), V(0.025f, -0.5f), V(0.035f, 0.5f), V(0, 0.52f) }, Hex("#d9b07a"));
        }
        return root;
    }

    static GameObject Vitamin()
    {
        var root = new GameObject("vitamin");
        Lathe(root, Vector3.zero, new[] { V(0, 0), V(0.3f, 0), V(0.34f, 0.06f), V(0.34f, 0.7f), V(0.26f, 0.84f), V(0.2f, 0.86f), V(0, 0.86f) }, Hex("#f6a13a"), 0.6f);
        Lathe(root, Vector3.zero, new[] { V(0, 0.84f), V(0.22f, 0.84f), V(0.225f, 1.04f), V(0.2f, 1.07f), V(0, 1.07f) }, White);
        Lathe(root, Vector3.zero, new[] { V(0, 0.22f), V(0.347f, 0.22f), V(0.347f, 0.58f), V(0, 0.58f) }, White);
        Box(root, new Vector3(0, 0.4f, -0.35f), new Vector3(0.24f, 0.08f, 0.02f), 0.01f, Orange);
        Box(root, new Vector3(0, 0.4f, -0.35f), new Vector3(0.08f, 0.24f, 0.02f), 0.01f, Orange);
        for (int i = 0; i < 3; i++)
        {
            var pill = Group(root, "pill", new Vector3(0.48f + i * 0.13f, 0.06f, -0.22f + i * 0.16f), new Vector3(0, i * 50f, 90f));
            Lathe(pill, Vector3.zero, new[] { V(0, -0.11f), V(0.05f, -0.09f), V(0.06f, 0), V(0, 0) }, Hex("#ffd166"));
            Lathe(pill, Vector3.zero, new[] { V(0, 0), V(0.06f, 0), V(0.05f, 0.09f), V(0, 0.11f) }, Orange);
        }
        return root;
    }

    static GameObject Tangerine()
    {
        var root = new GameObject("tangerine");
        Lathe(root, Vector3.zero, new[] { V(0, 0), V(0.4f, 0), V(0.62f, 0.3f), V(0.66f, 0.36f), V(0.6f, 0.36f), V(0.55f, 0.32f), V(0, 0.32f) }, Hex("#c99a5a"));
        var spots = new[] { new Vector3(-0.22f, 0.42f, 0.06f), new Vector3(0.22f, 0.42f, -0.06f), new Vector3(0.02f, 0.4f, -0.26f), new Vector3(0.04f, 0.68f, -0.04f), new Vector3(-0.02f, 0.42f, 0.28f) };
        foreach (var p in spots)
        {
            var fruit = Ball(root, p, new Vector3(0.36f, 0.3f, 0.36f), Hex("#f7922a"));
            Ball(root, p + new Vector3(0, 0.15f, 0), new Vector3(0.05f, 0.03f, 0.05f), Hex("#7a8f3a"));
        }
        var leaf = Ball(root, new Vector3(0.12f, 0.86f, -0.06f), new Vector3(0.22f, 0.03f, 0.1f), Leaf);
        leaf.transform.localRotation = Quaternion.Euler(0, 30f, 20f);
        return root;
    }

    static GameObject Plant()
    {
        var root = new GameObject("plant");
        Lathe(root, Vector3.zero, new[] { V(0, 0), V(0.3f, 0), V(0.4f, 0.55f), V(0.44f, 0.58f), V(0.44f, 0.66f), V(0, 0.66f) }, Hex("#d9774b"));
        Lathe(root, Vector3.zero, new[] { V(0, 0.6f), V(0.39f, 0.6f), V(0.39f, 0.62f), V(0, 0.62f) }, Hex("#6b4a35"));
        var leaves = new[] { (0f, 30f, 0.85f), (72f, 42f, 0.75f), (144f, 28f, 0.9f), (216f, 46f, 0.7f), (288f, 34f, 0.8f), (36f, 8f, 0.65f) };
        foreach (var (yaw, tilt, len) in leaves)
        {
            var stem = Group(root, "stem", new Vector3(0, 0.6f, 0), new Vector3(0, yaw, 0));
            var arm = Group(stem, "arm", Vector3.zero, new Vector3(tilt, 0, 0));
            Lathe(arm, Vector3.zero, new[] { V(0, 0), V(0.022f, 0), V(0.018f, len * 0.7f), V(0, len * 0.72f) }, Hex("#5f9a45"));
            var blade = Ball(arm, new Vector3(0, len * 0.78f, -0.08f), new Vector3(0.42f * len, 0.04f, 0.5f * len), Leaf);
            blade.transform.localRotation = Quaternion.Euler(-28f, 0, 0);
        }
        return root;
    }

    static GameObject Lamp()
    {
        var root = new GameObject("lamp");
        Lathe(root, Vector3.zero, new[] { V(0, 0), V(0.38f, 0), V(0.4f, 0.04f), V(0.34f, 0.1f), V(0, 0.12f) }, Navy);
        var lower = Group(root, "lower", new Vector3(0, 0.1f, 0), new Vector3(0, 0, -18f));
        Lathe(lower, Vector3.zero, new[] { V(0, 0), V(0.035f, 0), V(0.035f, 0.8f), V(0, 0.8f) }, Gold);
        Ball(lower, new Vector3(0, 0.8f, 0), Vector3.one * 0.1f, Gold);
        var upper = Group(lower, "upper", new Vector3(0, 0.8f, 0), new Vector3(0, 0, 72f));
        Lathe(upper, Vector3.zero, new[] { V(0, 0), V(0.03f, 0), V(0.03f, 0.55f), V(0, 0.55f) }, Gold);
        var shade = Group(upper, "shade", new Vector3(0, 0.6f, 0), new Vector3(0, 0, 70f));
        Lathe(shade, Vector3.zero, new[] { V(0, 0.08f), V(0.1f, 0.08f), V(0.32f, -0.22f), V(0.34f, -0.26f), V(0.3f, -0.26f), V(0.09f, 0.03f), V(0, 0.03f) }, Hex("#f2b544"));
        var bulb = Ball(shade, new Vector3(0, -0.14f, 0), Vector3.one * 0.18f, Hex("#fff3c4"));
        Glow(bulb, Hex("#ffe9a0"));
        return root;
    }

    static GameObject AlarmClock()
    {
        var root = new GameObject("clock");
        var face = Group(root, "face", new Vector3(0, 0.55f, 0), new Vector3(-90f, 0, 0));
        Lathe(face, Vector3.zero, new[] { V(0, -0.18f), V(0.46f, -0.18f), V(0.52f, -0.12f), V(0.52f, 0.12f), V(0.46f, 0.18f), V(0, 0.18f) }, Mint);
        Lathe(face, Vector3.zero, new[] { V(0, 0.17f), V(0.42f, 0.17f), V(0.42f, 0.19f), V(0, 0.19f) }, White);
        var hands = Group(root, "hands", new Vector3(0, 0.55f, -0.2f), Vector3.zero);
        var h1 = Box(hands, new Vector3(0, 0.1f, 0), new Vector3(0.05f, 0.24f, 0.02f), 0.01f, Charcoal);
        var h2 = Box(hands, new Vector3(0.12f, 0.05f, 0), new Vector3(0.05f, 0.3f, 0.02f), 0.01f, Charcoal);
        h2.transform.localRotation = Quaternion.Euler(0, 0, -60f);
        h2.transform.localPosition = new Vector3(0.12f, -0.07f, 0);
        Ball(hands, new Vector3(0, 0, -0.01f), Vector3.one * 0.07f, Red);
        for (int i = 0; i < 12; i++)
        {
            float a = i * Mathf.PI / 6f;
            Ball(hands, new Vector3(Mathf.Sin(a) * 0.33f, Mathf.Cos(a) * 0.33f, 0.005f), Vector3.one * (i % 3 == 0 ? 0.06f : 0.035f), Navy);
        }
        for (int s = -1; s <= 1; s += 2)
        {
            var bell = Group(root, "bell", new Vector3(s * 0.32f, 1.05f, 0.02f), new Vector3(0, 0, -s * 28f));
            Lathe(bell, Vector3.zero, new[] { V(0, 0), V(0.2f, 0), V(0.19f, 0.08f), V(0.12f, 0.17f), V(0, 0.19f) }, Gold);
            var leg = Group(root, "leg", new Vector3(s * 0.3f, 0.04f, 0.02f), new Vector3(0, 0, s * 22f));
            Lathe(leg, Vector3.zero, new[] { V(0, 0), V(0.05f, 0), V(0.04f, 0.16f), V(0, 0.16f) }, Charcoal);
        }
        Box(root, new Vector3(0, 1.17f, 0.02f), new Vector3(0.12f, 0.08f, 0.08f), 0.03f, Charcoal);
        return root;
    }

    static GameObject Nameplate()
    {
        var root = new GameObject("nameplate");
        Box(root, new Vector3(0, 0.07f, 0), new Vector3(1.6f, 0.14f, 0.5f), 0.04f, DarkWood);
        var plate = Group(root, "plate", new Vector3(0, 0.3f, 0.02f), new Vector3(-22f, 0, 0));
        Box(plate, Vector3.zero, new Vector3(1.45f, 0.38f, 0.07f), 0.03f, Gold);
        Box(plate, new Vector3(0, 0, -0.038f), new Vector3(1.28f, 0.26f, 0.01f), 0.01f, Hex("#2b3a44"));
        for (int i = 0; i < 3; i++)
            Box(plate, new Vector3(-0.36f + i * 0.36f, 0, -0.047f), new Vector3(0.22f, 0.12f, 0.01f), 0.01f, Hex("#f6d77a"));
        return root;
    }

    static GameObject Trophy()
    {
        var root = new GameObject("trophy");
        Box(root, new Vector3(0, 0.12f, 0), new Vector3(0.62f, 0.24f, 0.62f), 0.04f, Navy);
        Box(root, new Vector3(0, 0.13f, -0.312f), new Vector3(0.42f, 0.1f, 0.01f), 0.01f, Gold);
        Lathe(root, Vector3.zero, new[] { V(0, 0.24f), V(0.22f, 0.24f), V(0.2f, 0.3f), V(0.07f, 0.36f), V(0.06f, 0.5f), V(0.1f, 0.56f), V(0.13f, 0.6f), V(0.34f, 0.72f), V(0.42f, 1.0f), V(0.43f, 1.12f), V(0.39f, 1.13f), V(0, 1.0f) }, Gold);
        for (int s = -1; s <= 1; s += 2)
        {
            var h = Group(root, "handle", new Vector3(s * 0.43f, 0.9f, 0), new Vector3(0, 0, 0));
            var ring = Torus(h, Vector3.zero, 0.14f, 0.035f, Gold);
            ring.transform.localRotation = Quaternion.Euler(90f, 0, 0);
        }
        return root;
    }

    // --- Mesh helpers -----------------------------------------------------------

    static Vector2 V(float r, float y) => new Vector2(r, y);

    static GameObject Group(GameObject parent, string name, Vector3 pos, Vector3 euler)
    {
        var g = new GameObject(name);
        g.transform.SetParent(parent.transform, false);
        g.transform.localPosition = pos;
        g.transform.localRotation = Quaternion.Euler(euler);
        return g;
    }

    static GameObject Part(GameObject parent, Mesh mesh, Vector3 pos, Color color, float gloss = 0.3f)
    {
        var go = new GameObject(mesh.name);
        go.transform.SetParent(parent.transform, false);
        go.transform.localPosition = pos;
        go.AddComponent<MeshFilter>().sharedMesh = mesh;
        var mr = go.AddComponent<MeshRenderer>();
        mr.sharedMaterial = Mat(color, gloss);
        mr.shadowCastingMode = ShadowCastingMode.On;
        mr.receiveShadows = true;
        return go;
    }

    static Material Mat(Color color, float gloss)
    {
        var key = new Color(color.r, color.g, color.b, gloss);
        if (Mats.TryGetValue(key, out var m))
            return m;
        m = new Material(Shader.Find("Standard")) { color = color };
        m.SetFloat("_Glossiness", gloss);
        m.SetFloat("_Metallic", 0f);
        Mats[key] = m;
        return m;
    }

    static void Glow(GameObject go, Color color)
    {
        var m = new Material(go.GetComponent<MeshRenderer>().sharedMaterial);
        m.EnableKeyword("_EMISSION");
        m.SetColor("_EmissionColor", color * 0.9f);
        go.GetComponent<MeshRenderer>().sharedMaterial = m;
    }

    static GameObject Ball(GameObject parent, Vector3 pos, Vector3 scale, Color color)
    {
        var go = Part(parent, SphereMesh(), pos, color);
        go.transform.localScale = scale;
        return go;
    }

    static Mesh _sphere;
    static Mesh SphereMesh()
    {
        if (_sphere)
            return _sphere;
        var prof = new List<Vector2>();
        for (int i = 0; i <= 16; i++)
        {
            float a = -Mathf.PI * 0.5f + Mathf.PI * i / 16f;
            prof.Add(new Vector2(Mathf.Cos(a) * 0.5f, Mathf.Sin(a) * 0.5f));
        }
        _sphere = LatheMesh(prof.ToArray(), 32, true);
        _sphere.name = "sphere";
        return _sphere;
    }

    /// Rounded box: a subdivided cube whose vertices are pulled onto an inner
    /// box and pushed out by the corner radius, giving smooth soft edges.
    static GameObject Box(GameObject parent, Vector3 pos, Vector3 size, float radius, Color color)
    {
        return Part(parent, RoundedBoxMesh(size, radius), pos, color, 0.22f);
    }

    static Mesh RoundedBoxMesh(Vector3 size, float radius)
    {
        radius = Mathf.Min(radius, size.x * 0.5f, size.y * 0.5f, size.z * 0.5f);
        var inner = size * 0.5f - Vector3.one * radius;
        const int n = 8;
        var verts = new List<Vector3>();
        var norms = new List<Vector3>();
        var tris = new List<int>();
        var faces = new[] { Vector3.right, Vector3.left, Vector3.up, Vector3.down, Vector3.forward, Vector3.back };
        foreach (var f in faces)
        {
            var u = new Vector3(f.y, f.z, f.x);
            var v = Vector3.Cross(f, u);
            int start = verts.Count;
            for (int i = 0; i <= n; i++)
            for (int j = 0; j <= n; j++)
            {
                var p = f + u * (i / (float)n * 2f - 1f) + v * (j / (float)n * 2f - 1f);
                var cube = Vector3.Scale(p, size * 0.5f);
                var clamped = new Vector3(Mathf.Clamp(cube.x, -inner.x, inner.x), Mathf.Clamp(cube.y, -inner.y, inner.y), Mathf.Clamp(cube.z, -inner.z, inner.z));
                var dir = cube - clamped;
                var nrm = dir.sqrMagnitude > 1e-8f ? dir.normalized : f;
                verts.Add(clamped + nrm * radius);
                norms.Add(nrm);
            }
            for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++)
            {
                int a = start + i * (n + 1) + j, b = a + 1, c = a + n + 1, d = c + 1;
                tris.AddRange(new[] { a, c, b, b, c, d });
            }
        }
        var mesh = new Mesh { name = "box" };
        mesh.SetVertices(verts);
        mesh.SetNormals(norms);
        mesh.SetTriangles(tris, 0);
        mesh.RecalculateBounds();
        return mesh;
    }

    static GameObject Lathe(GameObject parent, Vector3 pos, Vector2[] profile, Color color, float gloss = 0.3f)
    {
        return Part(parent, LatheMesh(profile, 40, false), pos, color, gloss);
    }

    /// Revolves a (radius, height) profile around Y. Hard corners get split
    /// normals unless smooth is set, so cups keep crisp rims.
    static Mesh LatheMesh(Vector2[] profile, int segments, bool smooth)
    {
        var verts = new List<Vector3>();
        var norms = new List<Vector3>();
        var tris = new List<int>();
        for (int k = 0; k < profile.Length - 1; k++)
        {
            var p0 = profile[k];
            var p1 = profile[k + 1];
            var edge = p1 - p0;
            var n2 = new Vector2(edge.y, -edge.x).normalized;
            Vector2 na = n2, nb = n2;
            if (smooth)
            {
                na = ProfileNormal(profile, k);
                nb = ProfileNormal(profile, k + 1);
            }
            int start = verts.Count;
            for (int s = 0; s <= segments; s++)
            {
                float a = s * Mathf.PI * 2f / segments;
                float c = Mathf.Cos(a), sn = Mathf.Sin(a);
                verts.Add(new Vector3(p0.x * c, p0.y, p0.x * sn));
                norms.Add(new Vector3(na.x * c, na.y, na.x * sn).normalized);
                verts.Add(new Vector3(p1.x * c, p1.y, p1.x * sn));
                norms.Add(new Vector3(nb.x * c, nb.y, nb.x * sn).normalized);
            }
            for (int s = 0; s < segments; s++)
            {
                int a = start + s * 2, b = a + 1, c2 = a + 2, d = a + 3;
                tris.AddRange(new[] { a, b, c2, b, d, c2 });
            }
        }
        var mesh = new Mesh { name = "lathe" };
        mesh.SetVertices(verts);
        mesh.SetNormals(norms);
        mesh.SetTriangles(tris, 0);
        mesh.RecalculateBounds();
        return mesh;
    }

    static Vector2 ProfileNormal(Vector2[] p, int i)
    {
        var prev = p[Mathf.Max(i - 1, 0)];
        var next = p[Mathf.Min(i + 1, p.Length - 1)];
        var t = next - prev;
        return new Vector2(t.y, -t.x).normalized;
    }

    static GameObject Torus(GameObject parent, Vector3 pos, float major, float minor, Color color)
    {
        var prof = new List<Vector2>();
        for (int i = 0; i <= 20; i++)
        {
            float a = Mathf.PI * 2f * i / 20f;
            prof.Add(new Vector2(major + Mathf.Cos(a) * minor, -Mathf.Sin(a) * minor));
        }
        return Part(parent, LatheMesh(prof.ToArray(), 48, true), pos, color, 0.45f);
    }

    static Color Hex(string hex)
    {
        ColorUtility.TryParseHtmlString(hex, out var c);
        return c;
    }
}
