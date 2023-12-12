import SpriteKit

/// - Tag: TemplateLabelNode
class BoundingBoxNode: SKNode {
    init(_ boundingBox: CGRect, _ scale: CGSize?) {
        super.init()
        
        if (scale != nil) {
            self.xScale = 1/scale!.width
            self.yScale = 1/scale!.height
        }
        
        self.addBox(boundingBox, scale)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addBox(_ boundingBox: CGRect, _ scale: CGSize?) {
        let width = scale != nil ? boundingBox.width * scale!.width : boundingBox.width
        let height = scale != nil ? boundingBox.height * scale!.height : boundingBox.height
        print("BOUNDING BOX", boundingBox)
        print("SCALED", width, height)
        
        let boxNode = SKShapeNode(rectOf: CGSize(width: width, height: height))
        boxNode.lineWidth = 1
        boxNode.strokeColor = .red
        boxNode.fillColor = .clear
        boxNode.glowWidth = 0

        self.addChild(boxNode)
    }
    
}
