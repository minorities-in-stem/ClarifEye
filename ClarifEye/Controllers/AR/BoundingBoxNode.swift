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
        let width = boundingBox.width
        let height = boundingBox.height
        
        let boxNode = SKShapeNode(rectOf: CGSize(width: width, height: height))
        boxNode.lineWidth = 1
        boxNode.strokeColor = .red
        boxNode.fillColor = .clear
        boxNode.glowWidth = 0

        self.addChild(boxNode)
    }
    
}
