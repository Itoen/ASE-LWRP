using System;

namespace AmplifyShaderEditor
{
    [Serializable]
    [NodeAttributes("LWRP Vertex Light", "LWRP", "It works only for LWRP.")]
    public class LWRP_VertexLight_Node : ParentNode
    {
        protected override void CommonInit (int uniqueId)
        {
            base.CommonInit(uniqueId);
            AddInputPort(WirePortDataType.FLOAT3, true, "WorldPosition");
            AddInputPort(WirePortDataType.FLOAT3, true, "WorldNormal");
            AddOutputPort(WirePortDataType.COLOR, "Vertex Color");
        }

        public override string GenerateShaderForOutput (int outputId, ref MasterNodeDataCollector dataCollector, bool ignoreLocalvar)
        {
            string worldPosition = m_inputPorts[0].GenerateShaderForOutput(ref dataCollector, ignoreLocalvar);
            string worldNormal = m_inputPorts[1].GenerateShaderForOutput(ref dataCollector, ignoreLocalvar);
            return string.Format("VertexLighting({0},{1})", worldPosition, worldNormal);
        }
    }
}
