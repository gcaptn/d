# D

## Example usage

```lua
local key = "my-first-post"
local posts = D.getStore("posts")

posts:defaultTo({
  title = "Untitled",
  content = ""
})

posts:load(key)
  :andThen(function()
    local data = posts:get(key)
    data.title = "My first post"
    data.content = "Hello world!"
    posts:set(key, data)
    return posts:commit(key)
  end)
  :andThen(function()
    print("done!")
  end)
  :catch(function(err)
    print("something went wrong:", err)
  end)
```
