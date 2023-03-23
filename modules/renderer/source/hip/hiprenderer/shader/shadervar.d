/*
Copyright: Marcelo S. N. Mancini (Hipreme|MrcSnm), 2018 - 2021
License:   [https://creativecommons.org/licenses/by/4.0/|CC BY-4.0 License].
Authors: Marcelo S. N. Mancini

	Copyright Marcelo S. N. Mancini 2018 - 2021.
Distributed under the CC BY-4.0 License.
   (See accompanying file LICENSE.txt or copy at
	https://creativecommons.org/licenses/by/4.0/
*/
module hip.hiprenderer.shader.shadervar;
import hip.hiprenderer.shader.shader;
import hip.hiprenderer.renderer;
import hip.error.handler;
import hip.util.conv:to;
import hip.math.matrix;
import hip.api.graphics.color;

/**
*   Changes how the Shader behaves based on the backend
*/
enum ShaderHint : uint
{
    NONE = 0,
    GL_USE_BLOCK = 1<<0,
    GL_USE_STD_140 = 1<<1,
    D3D_USE_HLSL_4 = 1<<2,
    /** 
     * Meant for usage in uniform variables.
     * That means one Shader Variable may not be sent to the backend depending on its requirements.
     * An example for that is Array of Textures. In D3D11, it depends only on the resource being bound,
     * while on Metal and GL3, they are required to be inside a MTLBuffer or being sent as an Uniform.
     */ 
    Optional = 1 << 3
}

/**
*   Should not be used directly. The D type inference can already set that for you.
*   This is stored by the variable to know how to access itself and comunicate the shader.
*/
enum UniformType
{
    boolean,
    integer,
    integer_array,
    uinteger,
    uinteger_array,
    floating,
    floating2,
    floating3,
    floating4,
    floating2x2,
    floating3x3,
    floating4x4,
    floating_array,
    texture_array,
    none
}

/**
*   Struct that holds uniform/cbuffer information for Direct3D and OpenGL shaders. It can be any type.
*   Its data is accessed by the ShaderVariableLayout when sendVars is called. Thus, depending on its
*   corrensponding type, its data is uploaded to the GPU.
*/
struct ShaderVar
{
    import hip.util.data_structures:Array;
    import std.traits;
    void[] data;
    string name;
    ShaderTypes shaderType;
    UniformType type;
    size_t singleSize;
    bool isDynamicArrayReference;

    bool isDirty = true;

    size_t varSize() const{return data.length;}

    const T get(T)()
    {
        static if(isDynamicArray!T)
        {
            alias _t = typeof(T.init[0]);
            Array!(_t)* arr = cast(Array!(_t)*)data.ptr;
            return arr.data[0..arr.length];
        }
        else
            return *(cast(T*)this.data.ptr);
    }
    bool set(T)(T value, bool validateData)
    {
        import core.stdc.string;
        static assert(isNumeric!T ||
        isBoolean!T || isStaticArray!T || isDynamicArray!T ||
        is(T == Matrix3) || is(T == Matrix4) || is(T == HipColor) || is(T == HipColorf), "Invalid type "~T.stringof);

        static if(is(T == Matrix3) || is(T == Matrix4))
            value = HipRenderer.getMatrix(value);

        if(value.sizeof != varSize)
            return false;

        if(validateData && value == get!T)
            return true;

        isDirty = true;
        static if(isDynamicArray!T)
        {
            if(isDynamicArrayReference)
            {
                import hip.util.memory;
                alias TI = typeof(T.init[0]);
                if(data != null)
                {
                    Array!(TI)* arr = cast(Array!(TI)*)data;
                    arr.dispose();
                    free(data);
                }
                auto temp = Array!TI(value);
                data = temp.getRef;
            }
            else
                memcpy(data, value.ptr, varSize);
        }
        else
            memcpy(data, &value, varSize);
        return true;
    }
    auto opAssign(T)(T value)
    {
        static if(is(T == ShaderVar))
        {
            this.data = value.data;
            this.name = value.name;
            this.shaderType = value.shaderType;
            this.varSize = value.varSize;
            this.singleSize = value.singleSize;
        }
        else
            ErrorHandler.assertLazyExit(this.set(value), "Value set for '"~name~"' is invalid.");
        return this;
    }

    private void throwOnOutOfBounds(size_t index)
    {
        switch(type) with(UniformType)
        {
            case floating2:
                ErrorHandler.assertExit(index < 2, "Index out of bounds on shader variable "~name);
                break;
            case floating3:
                ErrorHandler.assertExit(index < 3, "Index out of bounds on shader variable "~name);
                break;
            case floating4:
                ErrorHandler.assertExit(index < 4, "Index out of bounds on shader variable "~name);
                break;
            case floating2x2:
                ErrorHandler.assertExit(index < 4, "Index out of bounds on shader variable "~name);
                break;
            case floating3x3:
                ErrorHandler.assertExit(index < 9, "Index out of bounds on shader variable "~name);
                break;
            case floating4x4:
                ErrorHandler.assertExit(index < 16, "Index out of bounds on shader variable "~name);
                break;
            default:
                ErrorHandler.assertExit(false, "opIndex is unsupported in var of type "~to!string(type));
        }
    }

    auto opIndexAssign(T)(T value, size_t index)
    {
        import core.stdc.string;
        throwOnOutOfBounds(index);
        ErrorHandler.assertExit(index*singleSize + T.sizeof <= varSize, "Value assign of type "~T.stringof~" at index "~to!string(index)~
        " is invalid for shader variable "~name~" of type "~to!string(type));

        if(isDynamicArrayReference)
            (cast(Array!(T)*)data)[index] = value;
        else
            memcpy(cast(ubyte*)data + singleSize*index, &value, T.sizeof);
        return value;
    }

    ref auto opIndex(size_t index)
    {
        throwOnOutOfBounds(index);
        switch(type) with(UniformType)
        {
            case floating2: return get!(float[2])[index];
            case floating3: return get!(float[3])[index];
            case floating4: return get!(float[4])[index];
            case floating2x2: return get!(float[4])[index];
            case floating3x3: return get!(float[9])[index];
            case floating4x4: return get!(float[16])[index];
            default:
                ErrorHandler.assertExit(false, "opIndex is unsupported in var of type "~to!string(type));
                return 0;
        }
    }

    static ShaderVar* create(ShaderTypes t, string varName, bool data){return ShaderVar.create(t, varName, &data, UniformType.boolean, data.sizeof, data.sizeof);}
    static ShaderVar* create(ShaderTypes t, string varName, int data){return ShaderVar.create(t, varName, &data, UniformType.integer, data.sizeof, data.sizeof);}
    static ShaderVar* create(ShaderTypes t, string varName, uint data){return ShaderVar.create(t, varName, &data, UniformType.uinteger, data.sizeof, data.sizeof);}
    static ShaderVar* create(ShaderTypes t, string varName, float data){return ShaderVar.create(t, varName, &data, UniformType.floating, data.sizeof, data.sizeof);}
    static ShaderVar* create(ShaderTypes t, string varName, float[2] data){return ShaderVar.create(t, varName, &data, UniformType.floating2, data.sizeof, data[0].sizeof);}
    static ShaderVar* create(ShaderTypes t, string varName, float[3] data){return ShaderVar.create(t, varName, &data, UniformType.floating3, data.sizeof, data[0].sizeof);}
    static ShaderVar* create(ShaderTypes t, string varName, float[4] data){return ShaderVar.create(t, varName, &data, UniformType.floating4, data.sizeof, data[0].sizeof);}
    static ShaderVar* create(ShaderTypes t, string varName, float[9] data){return ShaderVar.create(t, varName, &data, UniformType.floating3x3, data.sizeof, data[0].sizeof);}
    static ShaderVar* create(ShaderTypes t, string varName, float[16] data){return ShaderVar.create(t, varName, &data, UniformType.floating4x4, data.sizeof, data[0].sizeof);}
    static ShaderVar* create(ShaderTypes t, string varName, int[] data)
    {
        Array!int dRef = Array!int(data);
        return ShaderVar.create(t, varName, &dRef, UniformType.integer_array, dRef.sizeof, dRef[0].sizeof, true);
    }
    static ShaderVar* create(ShaderTypes t, string varName, uint[] data)
    {
        Array!uint dRef = Array!uint(data);
        return ShaderVar.create(t, varName, &dRef, UniformType.uinteger_array, dRef.sizeof, dRef[0].sizeof, true);
    }
    static ShaderVar* create(ShaderTypes t, string varName, float[] data)
    {
        Array!float dRef = Array!float(data);
        return ShaderVar.create(t, varName, &dRef, UniformType.floating_array, dRef.sizeof, dRef[0].sizeof, true);
    }

    protected static ShaderVar* create(
        ShaderTypes t,
        string varName,
        void* varData,
        UniformType type,
        size_t varSize,
        size_t singleSize,
        bool isDynamicArrayReference=false
    )
    {
        import core.stdc.string : memcpy;
        ErrorHandler.assertExit(isShaderVarNameValid(varName), "Variable '"~varName~"' is invalid.");
        ShaderVar* s = new ShaderVar();
        s.data = new void[varSize];
        memcpy(s.data.ptr, varData, varSize);   
        s.name = varName;
        s.shaderType = t;
        s.type = type;
        s.isDynamicArrayReference = isDynamicArrayReference;
        s.singleSize = singleSize;
        return s;
    }

    void dispose()
    {
        type = UniformType.none;
        shaderType = ShaderTypes.NONE;
        singleSize = 0;
        if(isDynamicArrayReference)
        {
            (cast(Array!(int)*)data).dispose();
        }
        else if(data != null)
        {
            import core.memory;
            GC.free(data.ptr);
            data = null;
        }
    }
}

struct ShaderVarLayout
{
    ShaderVar* sVar;
    uint alignment;
    uint size;
}

/**
*   This class is meant to be created together with the Shaders.
*   
*   Those are meant to wrap the cbuffer from Direct3D and Uniform Block from OpenGL.
*
*   By wrapping the uniforms/cbuffers layouts, it is much easier to send those variables from any API.
*/
class ShaderVariablesLayout
{
    import hip.hiprenderer.shader.var_packing;

    ShaderVarLayout[string] variables;
    private string[] namesOrder;
    string name;
    ShaderTypes shaderType;
    protected Shader owner;

    //Single block representation of variables content
    protected void* data;
    protected void* additionalData;
    protected bool isAdditionalAllocated;
    ///Can't unlock Layout
    private bool isLocked;

    ///The hint are used for the Shader backend as a notifier
    public immutable int hint;
    protected uint lastPosition;

    ///A function that must return a variable size when position = 0
    private VarPosition function(
        ref ShaderVar* v,
        uint lastAlignment = 0,
        bool isLast = false,
        uint n = float.sizeof)
    packFunc;


    /**
    *   Use the layout name for mentioning the uniform/cbuffer block name.
    *
    *   Its members are the ShaderVar* passed
    *
    *   Params:
    *       layoutName = From which block it will be accessed on the shader
    *       t = What is the shader type that holds those variables
    *       hint = Use ShaderHint for additional information, multiple hints may be passed
    *       variables = Usually you won't pass any and use .append for writing less
    */
    this(string layoutName, ShaderTypes t, uint hint, ShaderVar*[] variables ...)
    {
        import core.stdc.stdlib:malloc;
        this.name = layoutName;
        this.shaderType = t;
        this.hint = hint;

        switch(HipRenderer.getRendererType())
        {
            case HipRendererType.GL3:
                // if(hint & ShaderHint.GL_USE_STD_140)
                    packFunc = &glSTD140;
                break;
            case HipRendererType.D3D11:
                // if(hint & ShaderHint.D3D_USE_HLSL_4)
                    packFunc = &dxHLSL4;  
                break;
            case HipRendererType.METAL:
                packFunc = &glSTD140;
                break;
            case HipRendererType.NONE:
            default:break;
        }
        if(packFunc is null) packFunc = &nonePack;

        foreach(ShaderVar* v; variables)
        {
            ErrorHandler.assertExit(v.shaderType == t, "ShaderVariableLayout must contain only one shader type");
            ErrorHandler.assertExit((v.name in this.variables) is null, "Variable named "~v.name~" is already in the layout "~name);
            this.variables[v.name] = ShaderVarLayout(v, 0, 0);
            namesOrder~= v.name;
        }
        calcAlignment();
        data = malloc(getLayoutSize());
        ErrorHandler.assertExit(data != null, "Out of memory");
    }

    static ShaderVariablesLayout from(T)()
    {
        enum attr = __traits(getAttributes, T);
        static if(is(typeof(attr[0]) == HipShaderVertexUniform))
            enum shaderType = ShaderTypes.VERTEX;
        else static if(is(typeof(attr[0]) == HipShaderFragmentUniform))
            enum shaderType = ShaderTypes.FRAGMENT;
        else static assert(false, 
            "Type "~T.stringof~" doesn't have a HipShaderVertexUniform nor " ~ 
            "HipShaderFragmentUniform attached to it."
        );
        static assert(
            attr[0].name !is null,
            "HipShaderUniform "~T.stringof~" must contain a name as it is required to work in Direct3D 11"
        );
        ShaderVariablesLayout ret = new ShaderVariablesLayout(attr[0].name, shaderType, ShaderHint.NONE);
        static foreach(mem; __traits(allMembers, T))
        {
            ret.append(mem, __traits(getMember, T.init, mem));
        }

        return ret;
    }

    Shader getShader(){return owner;}
    void lock(Shader owner)
    {
        calcAlignment();
        this.owner = owner;
        this.isLocked = true;
    }

    /**
    *   Calculates the shader variables alignment based on the packFunc passed at startup.
    *   Those functions are based on the shader vendor and version. Align should be called
    *   always when there is a change on the layout.
    */
    final void calcAlignment()
    {
        uint lastAlign = 0;
        for(int i = 0; i < namesOrder.length; i++)
        {
            ShaderVarLayout* l = &variables[namesOrder[i]];
            VarPosition pos = packFunc(l.sVar, lastAlign, i == cast(int)namesOrder.length-1);
            l.size = pos.size;
            l.alignment = pos.startPos;
            lastAlign = pos.endPos;
        }
        lastPosition = lastAlign;
    }


    void* getBlockData()
    {
        import core.stdc.string:memcpy;
        foreach(v; variables)
            memcpy(data+v.alignment, v.sVar.data.ptr, v.size);
        return data;
    }

    protected ShaderVariablesLayout append(string varName, ShaderVar* v)
    {
        import core.stdc.stdlib:realloc;
        ErrorHandler.assertExit((varName in variables) is null, "Variable named "~varName~" is already in the layout "~name);
        ErrorHandler.assertExit(!isLocked, "Can't append ShaderVariable after it has been locked");
        variables[varName] = ShaderVarLayout(v, 0, 0);
        namesOrder~= varName;
        calcAlignment();
        this.data = realloc(this.data, getLayoutSize());
        ErrorHandler.assertExit(this.data != null, "Out of memory");
        return this;
    }

    /**
    *   Appends a new variable to this layout.
    *   Type is inferred.
    */
    ShaderVariablesLayout append(T)(string varName, T data)
    {
        return append(varName, ShaderVar.create(this.shaderType, varName, data));
    }

    final size_t getLayoutSize(){return lastPosition;}
    final void setAdditionalData(void* d, bool isAllocated)
    {
        this.additionalData = d;
        this.isAdditionalAllocated = isAllocated;
    }
    final const(void*) getAdditionalData() const {return cast(const(void*))additionalData;}

    auto opDispatch(string member)()
    {
        return variables[member].sVar;
    }

    void dispose()
    {
        import core.stdc.stdlib:free;
        foreach (ref v; variables)
        {
            v.sVar.dispose();
            v.alignment = 0;
            v.size = 0;
            v.sVar = null;
        }
        if(data != null)
            free(data);
        if(isAdditionalAllocated && additionalData != null)
            free(additionalData);
        additionalData = null;
        data = null;
    }
}


private bool isShaderVarNameValid(ref string varName)
{
    import hip.util.string : indexOf;
    
    return varName.length > 0 && 
    varName.indexOf(" ") == -1;
}