package com.rest.api.service

import com.rest.api.entity.Product
import com.rest.api.repository.ProductRepository
import org.springframework.stereotype.Service


@Service
class ProductServiceImpl(private val productRepository: ProductRepository) : ProductService {
    override fun getAllProducts(): List<Product> = productRepository.findAll()
    override fun getProductById(id: Long): Product? = productRepository.findById(id).orElse(null)
    override fun createProduct(product: Product): Product = productRepository.save(product)
    override fun deleteProduct(id: Long) = productRepository.deleteById(id)
}
