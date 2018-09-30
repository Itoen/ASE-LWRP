using System;

namespace AmplifyShaderEditor
{
    [Serializable]
    [NodeAttributes("SRP PI", "SRP", "It works only for SRP.")]
    public class SRP_PI_Node : ParentNode
    {
        protected override void CommonInit (int uniqueId)
        {
            base.CommonInit(uniqueId);
            AddOutputPort(WirePortDataType.FLOAT, "PI");
        }

        public override string GenerateShaderForOutput (int outputId, ref MasterNodeDataCollector dataCollector, bool ignoreLocalvar)
        {
            return "PI";
        }
    }
}
