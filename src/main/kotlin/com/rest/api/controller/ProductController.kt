package com.rest.api.controller

import com.rest.api.entity.Product
import com.rest.api.service.ProductService
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/products")
class ProductController(private val productService: ProductService) {

    @GetMapping
    fun getAllProducts(): List<Product> = productService.getAllProducts()

    @GetMapping("/{id}")
    fun getProductById(@PathVariable id: Long): Product? = productService.getProductById(id)

    @PostMapping
    fun createProduct(@RequestBody product: Product): Product = productService.createProduct(product)

    @DeleteMapping("/{id}")
    fun deleteProduct(@PathVariable id: Long) = productService.deleteProduct(id)
}
