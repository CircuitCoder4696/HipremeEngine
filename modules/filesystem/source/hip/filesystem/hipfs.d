/*
Copyright: Marcelo S. N. Mancini (Hipreme|MrcSnm), 2018 - 2021
License:   [https://creativecommons.org/licenses/by/4.0/|CC BY-4.0 License].
Authors: Marcelo S. N. Mancini

	Copyright Marcelo S. N. Mancini 2018 - 2021.
Distributed under the CC BY-4.0 License.
   (See accompanying file LICENSE.txt or copy at
	https://creativecommons.org/licenses/by/4.0/
*/
module hip.filesystem.hipfs;

public import hip.hipengine.api.filesystem.hipfs;
import hip.util.reflection;

private pure bool validatePath(string initial, string toAppend)
{
    import hip.util.array:lastIndexOf;
    import hip.util.string:split;
    import hip.util.system : sanitizePath;

    if(initial.length != 0 && initial[$-1] == '/')
        initial = initial[0..$-1];
    string newPath = initial.sanitizePath;
    toAppend = toAppend.sanitizePath;

    string[] appends = toAppend.split("/");

    foreach(a; appends)
    {
        if(a == "" || a == ".")
            continue;
        if(a == "..")
        {
            long lastInd = newPath.lastIndexOf('/');
            if(lastInd == -1)
                continue;
            newPath = newPath[0..cast(uint)lastInd];
        }
        else
            newPath~= "/"~a;
    }
    for(int i = 0; i < initial.length; i++)
        if(initial[i] != newPath[i])
            return false;
    return true;
}


version(none) abstract class HipFile : IHipFileItf
{
    immutable FileMode mode;
    immutable string path;
    ulong size;
    ulong cursor;
    @disable this();
    this(string path, FileMode mode)
    {
        this.mode = mode;
        this.path = path;
        open(path, mode);
        this.size = getSize();
    }
    ///Whence is the same from libc
    long seek(long count, int whence = SEEK_CUR)
    {
        switch(whence)
        {
            default:
            case SEEK_CUR:
                cursor+= count;
                break;
            case SEEK_END:
                cursor = size + count;
                break;
            case SEEK_SET:
                cursor = count;
                break;
        }
        return cast(long)cursor;
    }

    T[] rawRead(T)(T[] buffer)
    {
        read(cast(void*)buffer.ptr,buffer.length);
        return buffer;
    }
}


/**
* FileSystem access for specific platforms.
*/
class HipFileSystem
{
    protected __gshared static string defPath;
    protected __gshared static string initialPath = "";
    protected __gshared static string combinedPath;
    protected __gshared static bool hasSetInitial;
    protected __gshared static IHipFileSystemInteraction fs;

    protected __gshared static bool function(string path, out string errMessage)[] extraValidations;

    version(Android){import hip.filesystem.systems.android;}
    else version(UWP){import hip.filesystem.systems.uwp;}
    else version(HipDStdFile){import hip.filesystem.systems.dstd;}
    else {import hip.filesystem.systems.cstd;}
 
    
    public static void install(string path)
    {
        import hip.util.system : sanitizePath;
        if(!hasSetInitial)
        {
            initialPath = path.sanitizePath;
            version(Android){fs = new HipAndroidFileSystemInteraction();}
            // else version(UWP){fs = new HipUWPileSystemInteraction();}
            else version(PSVita){fs = new HipCStdioFileSystemInteraction();}
            else
            {
                version(HipDStdFile){}else{static assert(false, "HipDStdFile should be marked to be used.");}
                fs = new HipStdFileSystemInteraction();
            }
            setPath("");
            hasSetInitial = true;
        }
    }

    
    version(FunctionArrayAvailable)
    public static void install(string path,
    bool function(string path, out string errMessage)[] validations ...)
    {
        import hip.util.system : sanitizePath;
        if(!hasSetInitial)
        {
            install(path);
            foreach (v; validations){extraValidations~=v;}
        }
    }
    @ExportD public static string getPath(string path)
    {
        import hip.util.path:joinPath;
        import hip.util.system : sanitizePath;
        return joinPath(combinedPath, path.sanitizePath);
    }
    @ExportD public static bool isPathValid(string path){return validatePath(initialPath, defPath~path);}
    @ExportD public static bool isPathValidExtra(string path)
    {
        import hip.error.handler;
        import hip.util.system : sanitizePath;
        path = path.sanitizePath;
        string err;
        foreach (bool function(string, out string) validation; extraValidations)
        {
            if(!validation(path, err))
            {
                ErrorHandler.showErrorMessage("HipFileSystem validation error",
                "Path '"~path~"' failed at validation with error: '"~err~"'.");
                return false;
            }
        }
        return true;
    }

    @ExportD public static bool setPath(string path)
    {
        import hip.util.path:joinPath;
        import hip.util.system : sanitizePath;
        defPath = path.sanitizePath;
        combinedPath = joinPath(initialPath, defPath);
        return validatePath(initialPath, combinedPath);
    }

    @ExportD public static bool read(string path, out void[] output)
    {
        path = getPath(path);
        if(!isPathValid(path) || !isPathValidExtra(path))
            return false;
        return fs.read(path, output);
    }
    @ExportD public static bool read(string path, out ubyte[] output)
    {
        void[] data;
        bool ret = read(path, data);
        output = cast(ubyte[])data;
        return ret;
    }
    @ExportD public static bool readText(string path, out string output)
    {
        void[] data;
        bool ret = read(path, data);
        if(ret)
            output = cast(string)data;
        return ret;
    }

    version(HipDStdFile)
    {
        import std.stdio:File;
        public static bool getFile(string path, string opts, out File file)
        {
            if(!isPathValid(path) || !isPathValidExtra(path))
                return false;
            file = File(getPath(path), opts);
            return true;
        }

    } 

    @ExportD public static bool write(string path, void[] data)
    {
        if(!isPathValid(path))
            return false;
        return fs.write(getPath(path), data);
    }
    @ExportD public static bool exists(string path){return isPathValid(path) && fs.exists(getPath(path));}
    @ExportD public static bool remove(string path)
    {
        if(!isPathValid(path) || !isPathValidExtra(path))
            return false;
        return fs.remove(getPath(path));
    }
    @ExportD public static string getcwd()
    {
        return getPath("");
    }

    @ExportD public static bool absoluteExists(string path){return fs.exists(path);}
    @ExportD public static bool absoluteIsDir(string path){return fs.isDir(path);}
    @ExportD public static bool absoluteIsFile(string path){return fs.isFile(path);}

    @ExportD public static bool isDir(string path){return isPathValid(path) && fs.isDir(getPath(path));}
    @ExportD public static bool isFile(string path){return isPathValid(path) && fs.isFile(getPath(path));}

    @ExportD public static string writeCache(string cacheName, void[] data)
    {
        import hip.util.path:joinPath;
        string p = joinPath(initialPath, ".cache", cacheName);
        write(p, data);
        return p;
    }
}

alias HipFS = HipFileSystem;
