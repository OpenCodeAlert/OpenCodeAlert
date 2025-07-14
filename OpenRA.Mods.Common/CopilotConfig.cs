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


			// 这里指定 Copilot.yaml 文件的相对路径
			var filePath = Path.Combine(parentDirectory, "mods", "common", "Copilot.yaml");

			if (!File.Exists(filePath))
			{
				parentDirectory = Path.GetDirectoryName(parentDirectory);
				filePath = Path.Combine(parentDirectory, "mods", "common", "Copilot.yaml");
				if (!File.Exists(filePath))
				{
					Console.WriteLine($"文件路径无效: {filePath}");
					return;
				}
			}

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
