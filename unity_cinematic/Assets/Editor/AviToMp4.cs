// Encodes a Godot movie-writer recording (MJPEG AVI + PCM audio) into an
// H.264/AAC MP4 with Unity's built-in MediaEncoder, so gameplay videos need
// no external tools.
// Run: Unity -batchmode -projectPath unity_cinematic -executeMethod AviToMp4.Encode -quit
//            -aviIn <recording.avi> -mp4Out <video.mp4>
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using Unity.Collections;
using UnityEditor.Media;
using UnityEngine;

public static class AviToMp4
{
    class Avi
    {
        public int width, height;
        public double fps = 30;
        public int channels = 2, sampleRate = 48000, bits = 16, format = 1;
        public readonly List<(long offset, int size)> frames = new List<(long, int)>();
        public readonly List<(long offset, int size)> audio = new List<(long, int)>();
    }

    public static void Encode()
    {
        string input = Arg("-aviIn"), output = Arg("-mp4Out");
        var bytes = File.ReadAllBytes(input);
        var avi = new Avi();
        Walk(bytes, 12, bytes.Length, avi, "");
        Debug.Log($"AVI {avi.width}x{avi.height} @{avi.fps:0.##} fps, {avi.frames.Count} frames, audio {avi.channels}ch {avi.sampleRate}Hz {avi.bits}bit");

        var samples = DecodeAudio(bytes, avi);
        int fps = (int)Math.Round(avi.fps);
        var video = new VideoTrackAttributes
        {
            frameRate = new MediaRational(fps),
            width = (uint)avi.width,
            height = (uint)avi.height,
            includeAlpha = false,
            bitRateMode = UnityEditor.VideoBitrateMode.High,
        };
        var sound = new AudioTrackAttributes
        {
            sampleRate = new MediaRational(avi.sampleRate),
            channelCount = (ushort)avi.channels,
            language = "ko",
        };
        int perFrame = avi.sampleRate / fps * avi.channels;
        var jpeg = new Texture2D(2, 2);
        var frame = new Texture2D(avi.width, avi.height, TextureFormat.RGBA32, false);
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(output)));
        using (var encoder = new MediaEncoder(output, video, sound))
        using (var chunk = new NativeArray<float>(perFrame, Allocator.Persistent))
        {
            int cursor = 0;
            var buffer = new float[perFrame];
            for (int i = 0; i < avi.frames.Count; i++)
            {
                var (offset, size) = avi.frames[i];
                var data = new byte[size];
                Buffer.BlockCopy(bytes, (int)offset, data, 0, size);
                jpeg.LoadImage(data);
                frame.SetPixels32(jpeg.GetPixels32());
                frame.Apply();
                encoder.AddFrame(frame);
                Array.Clear(buffer, 0, perFrame);
                int take = Math.Min(perFrame, Math.Max(0, samples.Length - cursor));
                Array.Copy(samples, cursor, buffer, 0, take);
                cursor += perFrame;
                chunk.CopyFrom(buffer);
                encoder.AddSamples(chunk);
                if (i % 300 == 0)
                    Debug.Log($"ENCODE {i}/{avi.frames.Count}");
            }
        }
        Debug.Log($"MP4 {output}");
    }

    static string Arg(string name)
    {
        var args = Environment.GetCommandLineArgs();
        int i = Array.IndexOf(args, name);
        if (i < 0 || i + 1 >= args.Length)
            throw new ArgumentException($"missing {name}");
        return args[i + 1];
    }

    static string Fourcc(byte[] b, int at) => Encoding.ASCII.GetString(b, at, 4);

    /// Walks RIFF chunks; LIST chunks recurse. Records stream headers and the
    /// offsets of every video (00dc/00db) and audio (01wb) chunk in 'movi'.
    static void Walk(byte[] b, int start, int end, Avi avi, string streamType)
    {
        int p = start;
        while (p + 8 <= end)
        {
            string id = Fourcc(b, p);
            int size = BitConverter.ToInt32(b, p + 4);
            int body = p + 8;
            if (size < 0 || body + size > b.Length)
                break;
            switch (id)
            {
                case "LIST":
                    Walk(b, body + 4, body + size, avi, streamType);
                    break;
                case "avih":
                    avi.fps = 1e6 / Math.Max(1, BitConverter.ToInt32(b, body));
                    avi.width = BitConverter.ToInt32(b, body + 32);
                    avi.height = BitConverter.ToInt32(b, body + 36);
                    break;
                case "strh":
                    streamType = Fourcc(b, body);
                    break;
                case "strf":
                    if (streamType == "auds")
                    {
                        avi.format = BitConverter.ToUInt16(b, body);
                        avi.channels = BitConverter.ToUInt16(b, body + 2);
                        avi.sampleRate = BitConverter.ToInt32(b, body + 4);
                        avi.bits = BitConverter.ToUInt16(b, body + 14);
                    }
                    break;
                case "00dc":
                case "00db":
                    avi.frames.Add((body, size));
                    break;
                case "01wb":
                    avi.audio.Add((body, size));
                    break;
            }
            p = body + size + (size & 1);
        }
    }

    static float[] DecodeAudio(byte[] b, Avi avi)
    {
        int bytesPer = avi.bits / 8;
        long total = 0;
        foreach (var (_, size) in avi.audio)
            total += size / bytesPer;
        var outSamples = new float[total];
        long k = 0;
        foreach (var (offset, size) in avi.audio)
        {
            for (int i = 0; i + bytesPer <= size; i += bytesPer)
            {
                int at = (int)offset + i;
                float v;
                if (avi.format == 3 && bytesPer == 4)
                    v = BitConverter.ToSingle(b, at);
                else if (bytesPer == 4)
                    v = BitConverter.ToInt32(b, at) / 2147483648f;
                else
                    v = BitConverter.ToInt16(b, at) / 32768f;
                outSamples[k++] = v;
            }
        }
        return outSamples;
    }
}
