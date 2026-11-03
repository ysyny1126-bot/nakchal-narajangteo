// Story clips for 조달청 사원 키우기: the game's purpose (played after the
// player names their character) and a short quest brief before each episode.
// Stages the PPS career office and both mascots exported from Godot
// (scripts/dev/gltf_export.gd) and renders 1280x720 JPG frames per clip into
// build/unity_frames/<clip>/. scripts/dev/frames_to_video.gd turns them into .ogv.
// Run: Unity -batchmode -projectPath unity_cinematic -executeMethod BriefingRenderer.Render -quit
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

public static class BriefingRenderer
{
    const int Width = 1280;
    const int Height = 720;
    const int Fps = 30;
    const int UiLayer = 31;

    static readonly Color Navy = new Color32(0x24, 0x43, 0x5a, 255);
    static readonly Color Ink = new Color32(0x1f, 0x2a, 0x30, 255);
    static readonly Color Muted = new Color32(0x6b, 0x76, 0x7c, 255);
    static readonly Color Paper = new Color32(0xfb, 0xf8, 0xf1, 255);
    static readonly Color Orange = new Color32(0xe0, 0x7a, 0x35, 255);
    static readonly Color Gold = new Color32(0xff, 0xb0, 0x3a, 255);
    static readonly Color Green = new Color32(0x2f, 0x8a, 0x5b, 255);

    // Positions are in the Godot game's coordinates (x right, -z back wall).
    struct Shot
    {
        public float end, fov;
        public Vector3 camFrom, camTo, lookFrom, lookTo;
        public bool cheer;
    }

    // An overlay element shown between in and out (seconds).
    struct Beat
    {
        public float t0, t1;
        public string kind;     // caption | title | card
        public string a, b;     // caption: speaker, line · title: title, subtitle · card: kicker, heading
        public string[] lines;  // card rows
        public string foot;     // card footer
    }

    class Clip
    {
        public string name;
        public Shot[] shots;
        public Beat[] beats;
    }

    static Shot S(float end, float fov, Vector3 cf, Vector3 ct, Vector3 lf, Vector3 lt, bool cheer = false) =>
        new Shot { end = end, fov = fov, camFrom = cf, camTo = ct, lookFrom = lf, lookTo = lt, cheer = cheer };

    static Beat Cap(float t0, float t1, string who, string line) => new Beat { t0 = t0, t1 = t1, kind = "caption", a = who, b = line };
    static Beat Title(float t0, float t1, string title, string sub) => new Beat { t0 = t0, t1 = t1, kind = "title", a = title, b = sub };
    static Beat Card(float t0, float t1, string kicker, string heading, string[] lines, string foot) =>
        new Beat { t0 = t0, t1 = t1, kind = "card", a = kicker, b = heading, lines = lines, foot = foot };

    static readonly Vector3 V0 = new Vector3(0, 0.4f, -0.6f);

    static Shot[] EpisodeShots() => new[]
    {
        S(4.2f, 40, new Vector3(-1.6f, 5.6f, 6.6f), new Vector3(-0.6f, 4.8f, 5.8f), V0, new Vector3(0.1f, 0.4f, -0.8f)),
        S(10.6f, 42, new Vector3(2.4f, 3.6f, 5.8f), new Vector3(-1.8f, 3.6f, 5.8f), new Vector3(1.4f, 0.6f, 0.2f), new Vector3(-1.2f, 0.6f, 0.2f)),
        S(14.0f, 34, new Vector3(1.9f, 1.55f, 4.1f), new Vector3(1.5f, 1.3f, 3.3f), new Vector3(1.35f, 0.62f, 1.25f), new Vector3(1.35f, 0.58f, 1.25f), true),
    };

    static readonly Clip[] Clips =
    {
        new Clip
        {
            name = "intro",
            shots = new[]
            {
                S(5.5f, 40, new Vector3(0.6f, 7.2f, 7.6f), new Vector3(0.2f, 5.0f, 5.6f), new Vector3(0, 0.3f, -0.4f), new Vector3(0, 0.5f, -0.9f)),
                S(10.8f, 42, new Vector3(-2.2f, 2.5f, 4.8f), new Vector3(2.3f, 2.5f, 4.8f), new Vector3(-2.6f, 0.8f, 1.5f), new Vector3(2.7f, 0.8f, 1.1f)),
                S(16.0f, 34, new Vector3(1.9f, 1.6f, 4.2f), new Vector3(1.5f, 1.35f, 3.3f), new Vector3(1.35f, 0.65f, 1.25f), new Vector3(1.35f, 0.6f, 1.25f)),
                S(21.5f, 44, new Vector3(-1.8f, 4.6f, 6.2f), new Vector3(1.8f, 4.6f, 6.2f), V0, V0),
                S(26.0f, 34, new Vector3(1.4f, 1.35f, 5.0f), new Vector3(1.4f, 1.25f, 4.3f), new Vector3(1.35f, 1.05f, 1.25f), new Vector3(1.35f, 1.0f, 1.25f), true),
            },
            beats = new[]
            {
                Cap(0.6f, 5.3f, "달이", "조달청은 학교·병원·시청 같은 공공기관에\n필요한 물건과 서비스를 대신 사는 곳이에요."),
                Cap(5.7f, 10.6f, "달이", "그 돈은 모두 국민 세금이에요.\n그래서 공정하고 투명하게 사야 해요."),
                Cap(11.0f, 15.8f, "나라미", "오늘부터 저도 조달청 9급 주무관!\n업무를 하나씩 원칙대로 처리해 볼게요."),
                Card(16.2f, 21.3f, "게임 목표", "원칙을 지키는 공무원으로 성장하기", new[]
                {
                    "사무실을 걸어 다니며 업무 카드를 처리해요",
                    "규칙과 원칙에 맞는 선택이 언제나 정답",
                    "실적을 쌓아 9급에서 6급까지 승진해요",
                }, "실수해도 괜찮아요 · 게임 오버는 없어요"),
                Title(21.8f, 26.0f, "낙찰!", "조달청 사원 키우기"),
            },
        },
        new Clip
        {
            name = "ep1",
            shots = EpisodeShots(),
            beats = new[]
            {
                Title(0.3f, 4.0f, "EP1 · 첫 출근", "구매사업국 물품구매과 · 구매 규격과 입찰"),
                Card(4.4f, 10.4f, "이번 퀘스트", "○○시청 회의용 탁자 50개 구매", new[]
                {
                    "규격서에 특정 업체만 유리한 조건이 없는지 검토",
                    "기초금액·예정가격을 정하고 공고·개찰",
                    "1순위 업체를 사실대로 적격심사",
                }, "핵심 사건 · 수상한 실적 증명서"),
                Cap(10.8f, 14.0f, "박 팀장", "위험해 보이는 일은 꼼꼼히, 간단한 일은 빠르게!"),
            },
        },
        new Clip
        {
            name = "ep2",
            shots = EpisodeShots(),
            beats = new[]
            {
                Title(0.3f, 4.0f, "EP2 · 쇼핑몰 지킴이", "구매사업국 쇼핑몰운영과 · 종합쇼핑몰과 다수공급자계약"),
                Card(4.4f, 10.4f, "이번 퀘스트", "나라장터 종합쇼핑몰을 공정하게", new[]
                {
                    "새 상품 등록 신청을 꼼꼼히 심사",
                    "기관의 구매 문의에 규정대로 답변",
                    "수상하게 같이 움직이는 가격을 먼저 발견",
                }, "핵심 사건 · 담합 제보"),
                Cap(10.8f, 14.0f, "한 과장", "가격이 수상하게 움직이면 먼저 알아채야 해요."),
            },
        },
        new Clip
        {
            name = "ep3",
            shots = EpisodeShots(),
            beats = new[]
            {
                Title(0.3f, 4.0f, "EP3 · 현장으로", "공공물자국 품질관리과 · 납품·검사·대금 지급"),
                Card(4.4f, 10.4f, "이번 퀘스트", "탁자 50개, 제대로 제때 납품받기", new[]
                {
                    "납품 일정과 지체상금을 정확히 계산",
                    "현장에서 규격대로 왔는지 납품 검사",
                    "검사가 끝난 만큼 대금을 바르게 지급",
                }, "핵심 사건 · 연말의 무리한 지시"),
                Cap(10.8f, 14.0f, "오 과장", "연말이라 바쁘지만 원칙은 그대로!"),
            },
        },
    };

    static Vector3 G(Vector3 godot) => new Vector3(-godot.x, godot.y, godot.z);

    [MenuItem("Nakchal/Render Career Briefings")]
    public static void Render()
    {
        AssetDatabase.Refresh();
        string only = Arg("-clip");
        foreach (var clip in Clips)
        {
            if (only != null && only != clip.name) continue;
            RenderClip(clip);
        }
    }

    static void RenderClip(Clip clip)
    {
        EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        SetupLighting();
        var font = AssetDatabase.LoadAssetAtPath<Font>("Assets/Fonts/Pretendard-Bold.otf");
        var room = Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>("Assets/Imported/room_pps_office.glb"));
        TameEmission(room);
        var narami = Spawn("mascot_nareumi", G(new Vector3(1.05f, 0, 1.25f)), 8f);
        var dali = Spawn("mascot_dali", G(new Vector3(1.75f, 0, 1.4f)), -10f);

        var camGo = new GameObject("Camera");
        var cam = camGo.AddComponent<Camera>();
        cam.backgroundColor = new Color(0.12f, 0.17f, 0.18f);
        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.nearClipPlane = 0.05f;
        cam.farClipPlane = 60f;
        cam.cullingMask = ~(1 << UiLayer);

        var uiGo = new GameObject("UiCamera");
        uiGo.transform.position = new Vector3(0, 0, -500);
        var ui = uiGo.AddComponent<Camera>();
        ui.orthographic = true;
        ui.orthographicSize = Height * 0.5f;
        ui.clearFlags = CameraClearFlags.Nothing;
        ui.cullingMask = 1 << UiLayer;
        ui.nearClipPlane = 0.1f;
        ui.farClipPlane = 1000f;

        var overlay = new Overlay(font, clip.beats);

        var rt = new RenderTexture(Width, Height, 24, RenderTextureFormat.ARGB32) { antiAliasing = 8 };
        // UI is drawn over a resolved copy: a second camera on an MSAA target starts from an empty buffer.
        var flat = new RenderTexture(Width, Height, 24, RenderTextureFormat.ARGB32);
        var tex = new Texture2D(Width, Height, TextureFormat.RGB24, false);
        string outDir = Path.GetFullPath(Path.Combine(Application.dataPath, "../../build/unity_frames/" + clip.name));
        Directory.CreateDirectory(outDir);
        foreach (var f in Directory.GetFiles(outDir, "frame_*")) File.Delete(f);

        float total = clip.shots[clip.shots.Length - 1].end;
        int frames = Mathf.CeilToInt(total * Fps);
        for (int i = 0; i < frames; i++)
        {
            float t = i / (float)Fps;
            float start = 0f;
            var shot = clip.shots[0];
            for (int k = 0; k < clip.shots.Length; k++)
            {
                if (t < clip.shots[k].end) { shot = clip.shots[k]; start = k == 0 ? 0f : clip.shots[k - 1].end; break; }
            }
            float p = Mathf.InverseLerp(start, shot.end, t);
            float e = p * p * (3f - 2f * p);
            cam.fieldOfView = shot.fov;
            cam.transform.position = G(Vector3.Lerp(shot.camFrom, shot.camTo, e));
            cam.transform.LookAt(G(Vector3.Lerp(shot.lookFrom, shot.lookTo, e)));
            Animate(narami, t, 0f, shot.cheer, 8f);
            Animate(dali, t, 1.1f, shot.cheer, -10f);

            // Fade through dark at each cut and at both ends.
            float cut = Mathf.Min(t - start, shot.end - t);
            float dip = 1f - Mathf.Clamp01(cut / 0.3f);
            if (t < 0.5f) dip = 1f - t / 0.5f;
            if (total - t < 0.5f) dip = Mathf.Max(dip, 1f - (total - t) / 0.5f);
            overlay.Update(t, dip);

            cam.targetTexture = rt;
            cam.Render();
            Graphics.Blit(rt, flat);
            ui.targetTexture = flat;
            ui.Render();
            RenderTexture.active = flat;
            tex.ReadPixels(new Rect(0, 0, Width, Height), 0, 0);
            tex.Apply();
            File.WriteAllBytes(Path.Combine(outDir, $"frame_{i:D5}.jpg"), tex.EncodeToJPG(93));
        }
        RenderTexture.active = null;
        cam.targetTexture = null;
        ui.targetTexture = null;
        Debug.Log($"BRIEFING {clip.name}: {frames} frames to {outDir}");
    }

    static string Arg(string name)
    {
        var args = System.Environment.GetCommandLineArgs();
        int i = System.Array.IndexOf(args, name);
        return i >= 0 && i + 1 < args.Length ? args[i + 1] : null;
    }

    static GameObject Spawn(string name, Vector3 pos, float yaw)
    {
        var go = Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>($"Assets/Imported/{name}.glb"));
        go.transform.position = pos;
        go.transform.rotation = Quaternion.Euler(0, yaw, 0);
        go.transform.localScale = Vector3.one * 0.86f;
        return go;
    }

    static void Animate(GameObject m, float t, float phase, bool cheer, float yaw)
    {
        var pos = m.transform.position;
        float hop = cheer ? Mathf.Abs(Mathf.Sin(t * 5.2f + phase)) * 0.11f : Mathf.Abs(Mathf.Sin(t * 2.4f + phase)) * 0.02f;
        m.transform.position = new Vector3(pos.x, hop, pos.z);
        m.transform.rotation = Quaternion.Euler(0, yaw + Mathf.Sin(t * 1.2f + phase) * 10f, Mathf.Sin(t * 4.6f + phase) * 3f);
    }

    static void TameEmission(GameObject root)
    {
        foreach (var r in root.GetComponentsInChildren<Renderer>())
        {
            foreach (var m in r.sharedMaterials)
            {
                if (m == null) continue;
                foreach (var prop in new[] { "_EmissionColor", "emissiveFactor" })
                {
                    if (!m.HasProperty(prop)) continue;
                    var c = m.GetColor(prop);
                    if (c.maxColorComponent > 0.01f) m.SetColor(prop, c * 0.35f);
                }
            }
        }
    }

    static void SetupLighting()
    {
        RenderSettings.ambientMode = AmbientMode.Trilight;
        RenderSettings.ambientSkyColor = new Color(0.8f, 0.84f, 0.88f) * 0.85f;
        RenderSettings.ambientEquatorColor = new Color(0.64f, 0.6f, 0.54f) * 0.75f;
        RenderSettings.ambientGroundColor = new Color(0.36f, 0.31f, 0.27f) * 0.6f;
        RenderSettings.fog = false;
        QualitySettings.shadows = ShadowQuality.All;
        QualitySettings.shadowResolution = ShadowResolution.VeryHigh;
        QualitySettings.shadowDistance = 25f;
        QualitySettings.antiAliasing = 8;
        var key = new GameObject("Key").AddComponent<Light>();
        key.type = LightType.Directional;
        key.color = new Color(1f, 0.95f, 0.88f);
        key.intensity = 1.05f;
        key.shadows = LightShadows.Soft;
        key.shadowStrength = 0.65f;
        key.transform.rotation = Quaternion.Euler(52f, 30f, 0f);
        var fill = new GameObject("Fill").AddComponent<Light>();
        fill.type = LightType.Directional;
        fill.color = new Color(0.72f, 0.8f, 0.9f);
        fill.intensity = 0.3f;
        fill.transform.rotation = Quaternion.Euler(30f, -150f, 0f);
        var glow = new GameObject("RoomGlow").AddComponent<Light>();
        glow.type = LightType.Point;
        glow.color = new Color(1f, 0.86f, 0.66f);
        glow.intensity = 0.8f;
        glow.range = 7f;
        glow.transform.position = G(new Vector3(0.3f, 2.4f, 0.4f));
    }

    // Screen overlay on its own orthographic camera; 1 unit = 1 pixel, origin at center.
    class Overlay
    {
        readonly Font font;
        readonly Sprite round;
        readonly Beat[] beats;
        readonly List<List<(Object item, Color color, float delay)>> groups = new List<List<(Object, Color, float)>>();
        readonly SpriteRenderer dip;
        int order;

        public Overlay(Font font, Beat[] beats)
        {
            this.font = font;
            this.beats = beats;
            round = RoundSprite();
            dip = Panel(Vector2.zero, new Vector2(Width + 20, Height + 20), Color.black, 1000);
            foreach (var b in beats)
            {
                var g = new List<(Object, Color, float)>();
                switch (b.kind)
                {
                    case "caption": BuildCaption(b, g); break;
                    case "title": BuildTitle(b, g); break;
                    case "card": BuildCard(b, g); break;
                }
                groups.Add(g);
            }
        }

        void BuildCaption(Beat b, List<(Object, Color, float)> g)
        {
            int lines = b.b.Split('\n').Length;
            float h = 56 + lines * 34;
            float y = -Height * 0.5f + 34 + h * 0.5f;
            Add(g, Panel(new Vector2(0, y), new Vector2(880, h), new Color(1, 1, 1, 0.96f)), 0f);
            Add(g, Panel(new Vector2(-440 + 16 + 4, y), new Vector2(8, h - 28), Orange), 0f);
            float chipW = 34 + b.a.Length * 22;
            float top = y + h * 0.5f;
            Add(g, Panel(new Vector2(-440 + 40 + chipW * 0.5f, top), new Vector2(chipW, 38), Navy), 0f);
            Add(g, Text(b.a, new Vector2(-440 + 40 + chipW * 0.5f, top), 21, Color.white, TextAnchor.MiddleCenter), 0f);
            Add(g, Text(b.b, new Vector2(-440 + 44, y - 4), 27, Ink, TextAnchor.MiddleLeft, 1.15f), 0.1f);
        }

        void BuildTitle(Beat b, List<(Object, Color, float)> g)
        {
            Add(g, Panel(Vector2.zero, new Vector2(Width + 20, Height + 20), new Color(0.07f, 0.16f, 0.13f, 0.5f)), 0f);
            bool big = b.a.Length <= 4;
            float size = big ? 132 : 64;
            float ty = big ? 175 : 30;
            Add(g, Text(b.a, new Vector2(4, ty - 5), size, new Color(0.07f, 0.18f, 0.13f, 0.9f), TextAnchor.MiddleCenter), 0.05f);
            Add(g, Text(b.a, new Vector2(0, ty), size, big ? Gold : Color.white, TextAnchor.MiddleCenter), 0.05f);
            float w = 60 + b.b.Length * (big ? 34 : 22);
            float y = big ? 70 : -44;
            Add(g, Panel(new Vector2(0, y), new Vector2(w, big ? 70 : 52), Navy), 0.35f);
            Add(g, Text(b.b, new Vector2(0, y), big ? 38 : 24, Color.white, TextAnchor.MiddleCenter), 0.35f);
        }

        void BuildCard(Beat b, List<(Object, Color, float)> g)
        {
            Add(g, Panel(Vector2.zero, new Vector2(Width + 20, Height + 20), new Color(0.05f, 0.1f, 0.12f, 0.45f)), 0f);
            float w = 700, rows = b.lines.Length;
            float h = 210 + rows * 62;
            float top = h * 0.5f;
            Add(g, Panel(new Vector2(0, -6), new Vector2(w + 12, h + 12), new Color(0, 0, 0, 0.18f)), 0f);
            Add(g, Panel(Vector2.zero, new Vector2(w, h), Paper), 0f);
            Add(g, Panel(new Vector2(0, top - 5), new Vector2(w, 10), Orange), 0f);
            float chipW = 30 + b.a.Length * 20;
            Add(g, Panel(new Vector2(-w * 0.5f + 40 + chipW * 0.5f, top - 48), new Vector2(chipW, 36), Navy), 0f);
            Add(g, Text(b.a, new Vector2(-w * 0.5f + 40 + chipW * 0.5f, top - 48), 19, Color.white, TextAnchor.MiddleCenter), 0f);
            Add(g, Text(b.b, new Vector2(-w * 0.5f + 40, top - 102), 34, Ink, TextAnchor.MiddleLeft), 0.15f);
            for (int i = 0; i < rows; i++)
            {
                float y = top - 168 - i * 62;
                float d = 0.6f + i * 0.45f;
                Add(g, Panel(new Vector2(0, y), new Vector2(w - 80, 50), new Color(0.93f, 0.95f, 0.94f)), d);
                Add(g, Panel(new Vector2(-w * 0.5f + 66, y), new Vector2(30, 30), Green), d);
                Add(g, Text((i + 1).ToString(), new Vector2(-w * 0.5f + 66, y), 18, Color.white, TextAnchor.MiddleCenter), d);
                Add(g, Text(b.lines[i], new Vector2(-w * 0.5f + 96, y), 23, Ink, TextAnchor.MiddleLeft), d);
            }
            float fd = 0.6f + rows * 0.45f;
            Add(g, Text(b.foot, new Vector2(-w * 0.5f + 40, -top + 34), 20, Orange, TextAnchor.MiddleLeft), fd);
        }

        void Add(List<(Object, Color, float)> g, Object item, float delay)
        {
            Color c = item is SpriteRenderer sr ? sr.color : ((TextMesh)item).color;
            g.Add((item, c, delay));
            SetAlpha(item, c, 0f);
        }

        public void Update(float t, float dipAlpha)
        {
            for (int i = 0; i < beats.Length; i++)
            {
                var b = beats[i];
                foreach (var (item, color, delay) in groups[i])
                {
                    float a = Mathf.Clamp01((t - b.t0 - delay) / 0.3f) * Mathf.Clamp01((b.t1 - t) / 0.3f);
                    SetAlpha(item, color, a);
                    // Slight rise as elements appear.
                    var tr = ((Component)item).transform;
                    var basePos = tr.localPosition;
                    if (!rest.ContainsKey(tr)) rest[tr] = basePos;
                    tr.localPosition = rest[tr] + new Vector3(0, -12f * (1f - Mathf.Clamp01((t - b.t0 - delay) / 0.3f)), 0);
                }
            }
            dip.color = new Color(0, 0, 0, dipAlpha);
        }

        readonly Dictionary<Transform, Vector3> rest = new Dictionary<Transform, Vector3>();

        static void SetAlpha(Object item, Color c, float a)
        {
            c.a *= a;
            if (item is SpriteRenderer sr) sr.color = c;
            else ((TextMesh)item).color = c;
        }

        SpriteRenderer Panel(Vector2 center, Vector2 size, Color color, int sort = -1)
        {
            var go = new GameObject("Panel") { layer = UiLayer };
            go.transform.position = new Vector3(center.x, center.y, 0);
            var sr = go.AddComponent<SpriteRenderer>();
            sr.sprite = round;
            sr.drawMode = SpriteDrawMode.Sliced;
            sr.size = size;
            sr.color = color;
            sr.sortingOrder = sort >= 0 ? sort : order++;
            return sr;
        }

        TextMesh Text(string text, Vector2 pos, float px, Color color, TextAnchor anchor, float spacing = 1f)
        {
            var go = new GameObject("Text") { layer = UiLayer };
            go.transform.position = new Vector3(pos.x, pos.y, 0);
            var tm = go.AddComponent<TextMesh>();
            tm.font = font;
            tm.fontSize = 96;
            tm.characterSize = px / 9.6f;
            tm.anchor = anchor;
            tm.alignment = anchor == TextAnchor.MiddleCenter ? TextAlignment.Center : TextAlignment.Left;
            tm.lineSpacing = spacing;
            tm.color = color;
            tm.text = text;
            var mr = go.GetComponent<MeshRenderer>();
            mr.sharedMaterial = font.material;
            mr.sortingOrder = order++;
            return tm;
        }

        // 64px white rounded rect with a 20px corner, sliced so any size keeps its corners.
        static Sprite RoundSprite()
        {
            const int n = 64, r = 20;
            // UI is drawn over a resolved copy: a second camera on an MSAA target starts from an empty buffer.
        var flat = new RenderTexture(Width, Height, 24, RenderTextureFormat.ARGB32);
        var tex = new Texture2D(n, n, TextureFormat.RGBA32, false) { filterMode = FilterMode.Bilinear, wrapMode = TextureWrapMode.Clamp };
            for (int y = 0; y < n; y++)
            {
                for (int x = 0; x < n; x++)
                {
                    float cx = Mathf.Clamp(x + 0.5f, r, n - r), cy = Mathf.Clamp(y + 0.5f, r, n - r);
                    float d = Vector2.Distance(new Vector2(x + 0.5f, y + 0.5f), new Vector2(cx, cy));
                    tex.SetPixel(x, y, new Color(1, 1, 1, Mathf.Clamp01(r - d + 0.5f)));
                }
            }
            tex.Apply();
            return Sprite.Create(tex, new Rect(0, 0, n, n), new Vector2(0.5f, 0.5f), 2f, 0, SpriteMeshType.FullRect, new Vector4(r, r, r, r));
        }
    }
}
