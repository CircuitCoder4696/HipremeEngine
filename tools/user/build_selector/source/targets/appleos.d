module targets.appleos;
import commons;

ChoiceResult prepareAppleOS(Choice* c, ref Terminal t, ref RealTimeConsoleInput input, in CompilationOptions cOpts)
{
	environment["PATH"] = pathBeforeNewLdc;
	t.writelnHighlighted("LDC not supported for building AppleOS yet. Use system path.");
	t.flush;
	loadSubmodules(t, input);
	string phobosLib = configs["phobosLibPath"].str.getFirstExisting("libphobos2.a", "libphobos.a");
	if(phobosLib == null) throw new Error("Could not find your phobos library");
	string outputPhobos = buildNormalizedPath(
		configs["hipremeEnginePath"].str, 
		"build", "appleos", "HipremeEngine D",
		"static"
	);
	std.file.mkdirRecurse(outputPhobos);
	outputPhobos = buildNormalizedPath(outputPhobos, phobosLib.baseName);
	t.writelnSuccess("Copying phobos to XCode ", phobosLib, "->", outputPhobos);
	t.flush;
	std.file.copy(phobosLib, outputPhobos);
	putResourcesIn(t, buildNormalizedPath(configs["hipremeEnginePath"].str, "build", "appleos", "assets"));
	runEngineDScript(t, "releasegame.d", configs["gamePath"].str);

	environment["HIPREME_ENGINE"] = configs["hipremeEnginePath"].str;

	t.writelnSuccess("Building your game for AppleOS");
	t.flush;

	string script = import("appleosbuild.sh");
	t.writeln("Executing script appleosbuild.sh");
	t.flush;

	auto pid = spawnShell(script);
	wait(pid);

	return ChoiceResult.Continue;
}
