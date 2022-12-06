# await: true

::JS.npm_dependency "unxhr", "1.0.1"

module OpenURI
  `var __XMLHttpRequest__ = #{::JS.dynimport("unxhr", "XMLHttpRequest").__await__}`

  def self.request(uri)
    %x{
      var xhr = new __XMLHttpRequest__();
      xhr.open('GET', uri, false);
      xhr.responseType = 'arraybuffer';
      xhr.send();
      return xhr;
    }
  end

  def self.data(req)
    %x{
      var arrayBuffer = req.response;
      var byteArray = new Uint8Array(arrayBuffer);
      var result = []
      for (var i = 0; i < byteArray.byteLength; i++) {
        result.push(byteArray[i]);
      }
      return result;
    }
  end
end
