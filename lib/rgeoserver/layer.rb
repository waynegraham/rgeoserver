
module RGeoServer

    class Layer < ResourceInfo

      OBJ_ATTRIBUTES = {:enabled => 'enabled', :catalog => 'catalog', :name => 'name', :default_style => 'default_style', :alternate_styles => 'alternate_styles', :metadata => 'metadata', :attribution => 'attribution', :layer_type => 'type' }
      OBJ_DEFAULT_ATTRIBUTES = {:enabled => 'true', :catalog => nil, :name => nil, :default_style => nil, :alternate_styles => [], :metadata => {}, :attribution => {:logo_height => '0', :logo_width => '0', 'title' => ''}, :layer_type => nil }

      define_attribute_methods OBJ_ATTRIBUTES.keys
      update_attribute_accessors OBJ_ATTRIBUTES

      @@r = Confstruct::Configuration.new(:route => 'layers', :resource_name => 'layer')
  
      def self.resource_name
        @@r.resource_name
      end

      def self.create_method 
        :post 
      end

      def self.update_method 
        :put 
      end
 
      def self.root_xpath
        "//#{@@r.route}/#{@@r.resource_name}"
      end

      def self.member_xpath
        "//#{resource_name}"
      end

      def route
        @@r.route  
      end
  
      # No direct layer creation
      def create_route 
        nil 
      end

      def message
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.layer { 
            #xml.name @name
            xml.type_ layer_type  
            xml.enabled enabled
            xml.defaultStyle {
              xml.name default_style
            } 
            xml.styles {
              alternate_styles.each { |s|
                xml.style {
                  xml.name s
                }
              }
            } unless alternate_styles.empty?
            xml.resource(:class => resource.class.resource_name){
              xml.name resource.name 
            } unless resource.nil?
            xml.attribution {
              xml.title attribution['title'] unless attribution['title'].empty?
              xml.logoWidth attribution['logo_width']
              xml.logoHeight attribution['logo_height'] 
            } if !attribution['logo_width'].nil? && !attribution['logo_height'].nil?
          }
        end
        return builder.doc.to_xml 
      end

      # @param [RGeoServer::Catalog] catalog
      # @param [Hash] options
      # @option options [String] :name
      # @option options [String] :default_style
      # @option options [Array<String>] :alternate_styles
      def initialize catalog, options
        super({})
        _run_initialize_callbacks do
          @catalog = catalog
          @name = options[:name].strip
          #@default_style = options[:default_style] || ''
          #@alternate_styles = options[:alternate_styles] || []
        end        
        @route = route
      end

      def resource= r
        if r.is_a?(RGeoServer::Coverage) || r.is_a?(RGeoServer::FeatureType) 
          @resource = r
        else
          raise 'Unknown resource type'  
        end  
      end

      def resource
        @resource ||= begin
          unless profile['resource'].empty?
            data_type = profile['resource']['type']
            workspace = profile['resource']['workspace']
            name = profile['resource']['name']
            store = profile['resource']['store']

            case data_type
            when 'coverage'
              return RGeoServer::Coverage.new @catalog, :workspace => workspace, :coverage_store => store, :name => name
            when 'featureType'
              return RGeoServer::FeatureType.new @catalog, :workspace => workspace, :data_store => store, :name => name
            else
              raise 'Unknown resource type'  
            end
          else
            nil
          end
        rescue Exception => e
          nil
        end
      end
  
      # TODO: Simplify if necessary with "/layers/<l>/styles[.<format>]", as speficied in the API
      def get_default_style &block
        self.class.list Style, @catalog, @default_style, {:layer => self}, check_remote = false, &block
      end
 
      def get_alternate_styles &block
        self.class.list Style, @catalog, @alternate_styles, {:layer => self}, check_remote = false, &block
      end

      def profile_xml_to_hash profile_xml
        doc = profile_xml_to_ng profile_xml
        name = doc.at_xpath('//name/text()').text.strip
        link = doc.at_xpath('//resource//atom:link/@href', "xmlns:atom"=>"http://www.w3.org/2005/Atom").text.strip
        workspace, _, store = link.match(/workspaces\/(.*?)\/(.*?)\/(.*?)\/(.*?)\/#{name}.xml$/).to_a[1,3]

        h = {
          "name" => name, 
          "path" => doc.at_xpath('//path/text()').to_s,
          "default_style" => doc.at_xpath('//defaultStyle/name/text()').to_s,
          "alternate_styles" => doc.xpath('//styles/style/name/text()').collect{ |s| s.to_s},
          "type" => doc.at_xpath('//type/text()').to_s,
          "enabled" => doc.at_xpath('//enabled/text()').to_s,
          "attribution" => { 
            "title" => doc.at_xpath('//attribution/title/text()').to_s,
            "logo_width" => doc.at_xpath('//attribution/logoWidth/text()').to_s,
            "logo_height" => doc.at_xpath('//attribution/logoHeight/text()').to_s
          },
          "resource" => {
            "type" => doc.at_xpath('//resource/@class').to_s,
            "name" => doc.at_xpath('//resource/name/text()').to_s,
            "store" => store,
            "workspace" => workspace 
          },
          "metadata" => doc.xpath('//metadata/entry').inject({}){ |h, e| h.merge(e['key']=> e.text.to_s) } 
        }.freeze
        h  
      end
 
    end
end 