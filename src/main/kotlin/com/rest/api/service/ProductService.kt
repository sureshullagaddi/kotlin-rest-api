package com.rest.api.service

import com.rest.api.entity.Product

interface ProductService {

    fun getAllProducts(): List<Product>
    fun getProductById(id: Long): Product?
    fun createProduct(product: Product): Product
    fun updateProduct(id: Long, product: Product): Product?
    fun deleteProduct(id: Long)
    fun getProductByName(name: String): Product?

}