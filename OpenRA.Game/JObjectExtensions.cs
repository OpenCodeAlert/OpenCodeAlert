using Newtonsoft.Json.Linq;

namespace Newtonsoft.Json
{
	public static class JObjectExtensions
	{
		public static JToken TryGetFieldValue(this JObject jObject, string fieldName)
		{
			if (jObject == null || !jObject.TryGetValue(fieldName, out var value))
				return null;

			return value;
		}

		public static JToken TryGetFieldValue(this JToken token, string fieldName)
		{
			if (token is JObject jObject && jObject.TryGetValue(fieldName, out var value))
				return value;

			return null;
		}
	}
}
