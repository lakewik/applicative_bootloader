class TreeNode {
    public value: number;
    public children: TreeNode[];
  
    constructor(value: number, children: TreeNode[] = []) {
        this.value = value;
        this.children = children;
    }
  }
    
  class Tree {
    public root: TreeNode | null;
  
    constructor(leaves: number[], k: number) {
      this.root = this.buildTree(leaves.map(value => new TreeNode(value)), k, leaves.length);
    }
  
    private buildTree(nodes: TreeNode[], k: number, nodesCount: number): TreeNode | null {
      if (nodes.length === 1) {
        return nodes[0];
      }
  
      const nextLevel: TreeNode[] = [];
      let newNodeIndex = nodesCount;
      
      for (let i = 0; i < nodes.length; i += k) {
        const children = nodes.slice(i, i + k);
        if (children.length > 1) {
          newNodeIndex += 1;
        }
        const parent = new TreeNode(children.length === 1 ? children[0].value : newNodeIndex, children);
        nextLevel.push(parent);
      }
      
      return this.buildTree(nextLevel, k, newNodeIndex);
    }
  }
    
    const leaves = [1, 2, 3, 4, 5, 6, 7];
    const k = 2;
    
    const tree = new Tree(leaves, k);
    console.log(JSON.stringify(tree.root, null, 2));