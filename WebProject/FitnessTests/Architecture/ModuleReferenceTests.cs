using System.Xml.Linq;

namespace FitnessTests.Architecture;

/// <summary>
/// Verifies that module projects never take direct project references into other modules.
/// The only permitted cross-module reference is to the other module's .Public project.
///
/// Allowed:  Sample.Application  →  Sample.Domain          (same module)
/// Allowed:  Sample.Application  →  OtherModule.Public     (foreign .Public)
/// Allowed:  Sample.Application  →  Common.Library.*       (shared libraries)
/// Forbidden: Sample.Application →  OtherModule.Application / .Domain / .Infrastructure
/// </summary>
public class ModuleReferenceTests
{
    // Project name prefixes that are NOT considered module projects.
    private static readonly HashSet<string> NonModulePrefixes =
    [
        "WebProject",
        "Common",
        "FitnessTests",
    ];

    [Fact]
    public void ModuleProjects_MustNotReference_OtherModuleNonPublicProjects()
    {
        var solutionRoot = FindSolutionRoot();

        var projects = Directory
            .GetFiles(solutionRoot, "*.csproj", SearchOption.AllDirectories)
            .Where(p => !p.Contains($"{Path.DirectorySeparatorChar}obj{Path.DirectorySeparatorChar}"))
            .Select(p => new ProjectInfo(p))
            .ToList();

        var projectByName = projects.ToDictionary(p => p.Name);
        var moduleProjects = projects.Where(p => p.IsModuleProject).ToList();

        var violations = new List<string>();

        foreach (var project in moduleProjects)
        {
            foreach (var refName in project.ReferencedProjectNames)
            {
                if (!projectByName.TryGetValue(refName, out var referenced))
                    continue;

                // Only care about cross-module references to non-Public projects
                if (referenced.IsModuleProject
                    && referenced.ModuleName != project.ModuleName
                    && !referenced.IsPublic)
                {
                    violations.Add($"  {project.Name} → {referenced.Name}");
                }
            }
        }

        Assert.True(
            violations.Count == 0,
            $"Module projects must only reference other modules via their .Public project.{Environment.NewLine}" +
            $"Violations found:{Environment.NewLine}{string.Join(Environment.NewLine, violations)}");
    }

    private static string FindSolutionRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            if (dir.GetFiles("*.slnx").Length > 0 || dir.GetFiles("*.sln").Length > 0)
                return dir.FullName;
            dir = dir.Parent;
        }

        throw new InvalidOperationException(
            $"Could not locate solution root from '{AppContext.BaseDirectory}'.");
    }

    private sealed class ProjectInfo
    {
        public string Name { get; }
        public string ModuleName { get; }
        public bool IsPublic { get; }
        public bool IsModuleProject { get; }
        public IReadOnlyList<string> ReferencedProjectNames { get; }

        public ProjectInfo(string csprojPath)
        {
            Name = Path.GetFileNameWithoutExtension(csprojPath);
            ModuleName = Name.Split('.')[0];
            IsPublic = Name.EndsWith(".Public", StringComparison.Ordinal);
            IsModuleProject = !NonModulePrefixes.Contains(ModuleName);

            ReferencedProjectNames = XDocument.Load(csprojPath)
                .Descendants("ProjectReference")
                .Select(el => el.Attribute("Include")?.Value)
                .Where(v => v is not null)
                .Select(v => Path.GetFileNameWithoutExtension(v!))
                .ToList()!;
        }
    }
}
