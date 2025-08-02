//
//  SankeyDiagram.swift
//  Jars
//
//  Created by admin on 1. 8. 2025..
//

import SwiftUI
import WebKit

public struct SankeyDiagram: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    public var data: SankeyData
    private var options = SankeyOptions()
    fileprivate var onNodeTap: ((String) -> Void)?
    
    public init(_ data: SankeyData) {
        self.data = data
    }
    
    // MARK: – Modifier to register node taps
    public func onNodeTap(_ action: @escaping (String) -> Void) -> SankeyDiagram {
        var copy = self
        copy.onNodeTap = action
        return copy
    }
    
    // MARK: – UIViewRepresentable
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(onNodeTap: onNodeTap)
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        // 1. Create config & userContentController
        let userController = WKUserContentController()
        
        // 2. Register message handler for node taps
        if context.coordinator.onNodeTap != nil {
            userController.add(context.coordinator, name: Coordinator.messageHandlerName)
            
            // 3. Inject JS to hook clicks on `.node rect`
            let js = """
            document.addEventListener('DOMContentLoaded', () => {
              function hook() {
                // Assume d3 is loaded and sankey rendered
                d3.selectAll('.node rect').on('click', (event, d) => {
                  window.webkit.messageHandlers.\(Coordinator.messageHandlerName).postMessage(d.id || d.name);
                });
              }
              hook();
              // Re-hook after any redraw
              document.querySelector('svg').addEventListener('sankeyRebuilt', hook);
            });
            """
            let script = WKUserScript(source: js,
                                      injectionTime: .atDocumentEnd,
                                      forMainFrameOnly: true)
            userController.addUserScript(script)
        }
        
        let config = WKWebViewConfiguration()
        config.userContentController = userController
        
        // 4. Create & configure webView
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        
        loadHTML(webView)
        return webView
    }
    
    public func updateUIView(_ webView: WKWebView, context: Context) {
        loadHTML(webView)
    }
    
    // MARK: – View Modifiers (chainable)
    
    public func nodeAlignment(_ value: SankeyNodeAlignment) -> SankeyDiagram {
        var new = self; new.options.nodeAlignment = value; return new
    }
    public func nodeWidth(_ value: Double) -> SankeyDiagram {
        var new = self; new.options.nodeWidth = value; return new
    }
    public func nodePadding(_ value: Double) -> SankeyDiagram {
        var new = self; new.options.nodePadding = value; return new
    }
    public func nodeDefaultColor(_ color: Color) -> SankeyDiagram {
        var new = self; new.options.nodeDefaultColor = color; return new
    }
    public func nodeOpacity(_ value: Double) -> SankeyDiagram {
        var new = self; new.options.nodeOpacity = value; return new
    }
    public func linkDefaultColor(_ color: Color) -> SankeyDiagram {
        var new = self; new.options.linkDefaultColor = color; return new
    }
    public func linkOpacity(_ value: Double) -> SankeyDiagram {
        var new = self; new.options.linkOpacity = value; return new
    }
    public func linkColorMode(_ value: SankeyLinkColorMode?) -> SankeyDiagram {
        var new = self; new.options.linkColorMode = value; return new
    }
    public func labelPadding(_ value: Double) -> SankeyDiagram {
        var new = self; new.options.labelPadding = value; return new
    }
    public func labelColor(_ color: Color) -> SankeyDiagram {
        var new = self; new.options.labelColor = color; return new
    }
    public func labelOpacity(_ value: Double) -> SankeyDiagram {
        var new = self; new.options.labelOpacity = value; return new
    }
    public func labelFontSize(_ value: Double) -> SankeyDiagram {
        var new = self; new.options.labelFontSize = value; return new
    }
    public func labelFontFamily(_ value: String) -> SankeyDiagram {
        var new = self; new.options.labelFontFamily = value; return new
    }
    
    // MARK: – HTML Generation
    
    private func loadHTML(_ webView: WKWebView) {
        webView.loadHTMLString(generateHTML(), baseURL: nil)
    }
    
    private func generateHTML() -> String {
        let darkFlag = (colorScheme == .dark) ? "true" : "false"
        return """
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style> body { margin: 0 } svg { width:100%; height:100% } </style>
        </head>
        <body>
          <svg></svg>
          <script>\(SankeyResources.d3minjs)</script>
          <script>\(SankeyResources.d3sankeyminjs)</script>
          <script>
            const width = window.innerWidth, height = window.innerHeight;
            const isDark = \(darkFlag);
            const svg = d3.select('svg').attr('width',width).attr('height',height);
            const sankey = d3.sankey()
              .nodeId(d=>d.id)
              .nodeWidth(\(options.nodeWidth))
              .nodePadding(\(options.nodePadding))
              .nodeAlign(d3.sankey\(options.nodeAlignment.rawValue))
              .size([width,height]);
            const {nodes,links} = sankey(\(data));
            const defaultNodeColor = "\(options.nodeDefaultColor.hex(for: colorScheme))";
            const defaultLinkColor = "\(options.linkDefaultColor.hex(for: colorScheme))";
            const getColor = (data,fallback) => data ? (isDark?data.dark:data.light) : fallback;
            const getLinkColor = link => {
              let mode = "\(options.linkColorMode?.rawValue ?? "")";
              if (!mode) return getColor(link.hex, defaultLinkColor);
              let sc = getColor(link.source.hex, defaultNodeColor),
                  tc = getColor(link.target.hex, defaultNodeColor);
              if (mode==='source') return sc;
              if (mode==='target') return tc;
              if (mode==='source-target') {
                let id = 'grad'+link.index;
                let grad = svg.append('defs')
                  .append('linearGradient').attr('id',id)
                  .attr('gradientUnits','userSpaceOnUse')
                  .attr('x1',link.source.x1)
                  .attr('x2',link.target.x0);
                grad.append('stop').attr('offset','0%').attr('stop-color',sc);
                grad.append('stop').attr('offset','100%').attr('stop-color',tc);
                return 'url(#'+id+')';
              }
              return defaultLinkColor;
            };
            svg.append('g').attr('fill','none')
              .selectAll('.link').data(links).enter()
              .append('path').attr('class','link')
              .attr('d',d3.sankeyLinkHorizontal())
              .style('stroke',getLinkColor)
              .style('stroke-opacity',\(options.linkOpacity))
              .style('stroke-width',d=>Math.max(1,d.width));
            let nodeG = svg.append('g').selectAll('.node')
              .data(nodes).enter().append('g').attr('class','node');
            nodeG.append('rect')
              .attr('x',d=>d.x0).attr('y',d=>d.y0)
              .attr('width',d=>d.x1-d.x0).attr('height',d=>d.y1-d.y0)
              .style('fill',d=>getColor(d.hex,defaultNodeColor))
              .style('opacity',\(options.nodeOpacity))
              .style('stroke',d=>getColor(d.hex,defaultNodeColor))
              .style('stroke-opacity',\(options.nodeOpacity));
            nodeG.append('text')
              .attr('font-family','\(options.labelFontFamily)')
              .attr('font-size',\(options.labelFontSize))
              .attr('fill',isDark?'\(options.labelColor.dark.hex)':'\(options.labelColor.light.hex)')
              .style('opacity',\(options.labelOpacity))
              .attr('x',d=>d.x0<width/2?d.x1+\(options.labelPadding):d.x0-\(options.labelPadding))
              .attr('y',d=> (d.y1+d.y0)/2)
              .attr('dy','0.35em')
              .attr('text-anchor',d=>d.x0<width/2?'start':'end')
              .text(d=>d.label||d.id);
            // notify that sankey is drawn
            svg.node().dispatchEvent(new Event('sankeyRebuilt'));
          </script>
        </body>
        """
    }
    
    // MARK: – Coordinator
    
    public class Coordinator: NSObject, WKScriptMessageHandler {
        static let messageHandlerName = "sankeyNodeTapped"
        private let onNodeTap: ((String) -> Void)?
        
        init(onNodeTap: ((String) -> Void)?) {
            self.onNodeTap = onNodeTap
        }
        
        public func userContentController(_ userContentController: WKUserContentController,
                                          didReceive message: WKScriptMessage) {
            guard message.name == Coordinator.messageHandlerName,
                  let nodeID = message.body as? String else { return }
            onNodeTap?(nodeID)
        }
    }
}
