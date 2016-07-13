# ecsex [![Build Status](https://secure.travis-ci.org/toyama0919/ecsex.png?branch=master)](http://travis-ci.org/toyama0919/ecsex)

Aliyun API call by cli.

[see.](https://help.aliyun.com/document_detail/25485.html?spm=5176.doc25486.6.217.mrbZhI)

## Install
```
$ gem specific_install -l https://github.com/toyama0919/ecsex
```

## Setting
```
export ALIYUN_ACCESS_KEY_ID="XXXXXXXXXXXXXXXX"
export ALIYUN_ACCESS_KEY_SECRET="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
export ALIYUN_REGION=cn-beijing
```

## Synopsis

### show instances

    $ ecsex instances -n 'web*'

### show images

    $ ecsex images -n 'web*'

### create image

    $ ecsex create_image -n 'web01'

### copy instance

    $ ecsex copy -n 'web01' -p instance_name:web02 private_ip_address:172.17.0.12 host_name:web02

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new [Pull Request](../../pull/new/master)

## Information

* [Homepage](https://github.com/toyama0919/ecsex)
* [Issues](https://github.com/toyama0919/ecsex/issues)
* [Documentation](http://rubydoc.info/gems/ecsex/frames)
* [Email](mailto:toyama0919@gmail.com)

## Copyright

Copyright (c) 2016 toyama0919

See [LICENSE.txt](../LICENSE.txt) for details.
