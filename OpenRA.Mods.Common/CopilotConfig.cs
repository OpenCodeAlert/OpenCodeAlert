#region Copyright & License Information
/*
 * Copyright (c) The OpenRA Developers and Contributors
 * This file is part of OpenRA, which is free software. It is made
 * available to you under the terms of the GNU General Public License
 * as published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version. For more
 * information, see COPYING.
 */
#endregion

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace OpenRA.Mods.Common
{
	public static class CopilotsConfig
	{
		static Dictionary<string, List<string>> configNameToChinese;
		static Dictionary<string, List<string>> chineseToConfigName;

		public static void LoadConfig()
		{
			var parentDirectory = Path.GetDirectoryName(AppDomain.CurrentDomain.BaseDirectory);
			var baseDir = AppContext.BaseDirectory;
			string? filePath = null;

			// macOS .app: BaseDirectory = .../YourApp.app/Contents/MacOS/
			var macResources = Path.GetFullPath(Path.Combine(baseDir, "..", "..", "Resources", "mods", "common", "Copilot.yaml"));
			if (File.Exists(macResources))
				filePath = macResources;

			// Windows: BaseDirectory = ...\bin\Debug\net6.0\ or .exe所在目录
			var winPath = Path.Combine(parentDirectory, "mods", "common", "Copilot.yaml");
			if (filePath == null && File.Exists(winPath))
				filePath = winPath;

			if (filePath == null)
			{
				parentDirectory = Path.GetDirectoryName(parentDirectory);
				filePath = Path.Combine(parentDirectory, "mods", "common", "Copilot.yaml");
				if (!File.Exists(filePath))
				{
					Console.WriteLine("未找到 Copilot.yaml 配置文件");
					return;
				}
			}

			Console.WriteLine($"加载配置文件: {filePath}");

			var yamlNodes = MiniYaml.FromFile(filePath);
			var unitsNode = yamlNodes.FirstOrDefault(node => node.Key == "units")?.Value;

			configNameToChinese = new Dictionary<string, List<string>>();
			chineseToConfigName = new Dictionary<string, List<string>>();

			if (unitsNode != null)
			{
				foreach (var node in unitsNode.Nodes)
				{
					var configName = node.Key;
					var chineseNames = node.Value.Nodes.Select(n => n.Key).ToList();

					//if (!configNameToChinese.ContainsKey(configName))
					configNameToChinese[configName] = chineseNames;
					chineseToConfigName.TryAdd(configName, new List<string>());
					chineseToConfigName[configName].Add(configName);
					foreach (var chineseName in chineseNames)
					{
						chineseToConfigName.TryAdd(chineseName, new List<string>());
						chineseToConfigName[chineseName].Add(configName);
					}
				}
			}

			var nickName = yamlNodes.FirstOrDefault(node => node.Key == "nickname")?.Value;
			if (nickName != null)
			{
				foreach (var node in nickName.Nodes)
				{
					var chineseName = node.Key;
					var configNames = node.Value.Nodes.Select(n => n.Key).ToList();

					chineseToConfigName.TryAdd(chineseName, new List<string>());
					chineseToConfigName[chineseName].AddRange(configNames);
				}
			}
		}

		public static List<string> GetConfigNameByChinese(string chineseName)
		{
			var ret = chineseToConfigName.TryGetValue(chineseName, out var configName) ? configName : null;
			if (ret == null)
			{
				Console.WriteLine($"未知单位: {chineseName}");
				return new List<string>();
			}

			return ret;
		}

		public static string GetChineseByConfigName(string configName)
		{
			return configNameToChinese.TryGetValue(configName, out var chineseNames) ? chineseNames.First() : configName;
		}

	}
}
